# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.PassiveSocket do
  @moduledoc false

  use GenServer

  require Logger

  # Client

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def get_port(pid) do
    GenServer.call(pid, {:port}, :infinity)
  end

  def read(pid, consume_fun, consume_opts \\ []) do
    GenServer.cast(pid, {:read, self(), consume_fun, consume_opts})
  end

  def write(pid, data, opts \\ []) do
    GenServer.call(pid, {:write, data, opts}, :infinity)
  end

  def close(pid) do
    GenServer.call(pid, {:close}, :infinity)
  end

  # Server

  @impl GenServer
  def init(_opts) do
    min_port = Application.get_env(:ex_ftp, :min_passive_port)
    max_port = Application.get_env(:ex_ftp, :max_passive_port)

    {:ok, socket} =
      min_port..max_port
      |> Enum.shuffle()
      |> Enum.find_value(fn port ->
        case :gen_tcp.listen(port, [
               :binary,
               packet: :raw,
               active: false,
               reuseaddr: true,
               reuseport: false,
               send_timeout: :infinity,
               ip: {0, 0, 0, 0}
             ]) do
          {:ok, socket} ->
            Logger.info("Opening PASV connection on port #{port}")
            {:ok, socket}

          _ ->
            false
        end
      end)

    {:ok, %{socket: socket, write_socket: nil}}
  end

  @impl GenServer
  def handle_call({:port}, _from, %{socket: socket} = state) do
    {:reply, :inet.port(socket), state}
  end

  @impl GenServer
  def handle_call({:write, data, opts}, _from, %{socket: socket} = state) do
    write_socket =
      if write_socket = Map.get(state, :write_socket) do
        write_socket
      else
        {:ok, write_socket} = accept(socket)
        write_socket
      end

    if is_bitstring(data) do
      :gen_tcp.send(write_socket, data)
    else
      :ok = Enum.each(data, fn chunk -> :gen_tcp.send(write_socket, chunk) end)
    end

    :ok = :gen_tcp.send(write_socket, "\r\n")

    if Keyword.get(opts, :close_after_write, true) do
      :gen_tcp.close(write_socket)
      :gen_tcp.close(socket)
      {:reply, :ok, state}
    else
      {:reply, :ok, %{state | write_socket: write_socket}}
    end
  end

  @impl GenServer
  def handle_call({:close}, _from, %{socket: socket, write_socket: write_socket} = state) do
    Logger.info("Closing PASV connection.")
    write_socket && :gen_tcp.close(write_socket)
    :gen_tcp.close(socket)
    {:stop, :normal, :ok, state}
  end

  @impl GenServer
  def handle_cast({:read, worker, consume_fun, consume_opts}, %{socket: socket} = state) do
    :ok = consume_read(socket, consume_fun, consume_opts)

    :gen_tcp.close(socket)

    send(worker, :read_complete)

    {:noreply, state}
  end

  defp consume_read(socket, consume_fun, _consume_opts) do
    fn ->
      {:ok, read_socket} = accept(socket)
      read_socket
    end
    |> Stream.resource(
      fn read_socket ->
        case :gen_tcp.recv(read_socket, 0) do
          {:ok, data} ->
            {[data], read_socket}

          {:error, :closed} ->
            {:halt, read_socket}
        end
      end,
      fn read_socket -> :gen_tcp.close(read_socket) end
    )
    |> consume_fun.()

    :ok
  end

  defp accept(socket) do
    :gen_tcp.accept(socket)
  end
end
