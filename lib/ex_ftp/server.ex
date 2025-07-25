# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Server do
  @moduledoc false

  use GenServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    port = Keyword.get(opts, :port, 4040)

    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: true, reuseaddr: true]
      )

    Logger.info("Accepting connections on port #{port}")

    {:ok, %{socket: socket}, {:continue, :accept}}
  end

  @impl GenServer
  def handle_continue(:accept, %{socket: socket} = state) do
    accept(socket)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:accept, %{socket: socket} = state) do
    accept(socket)

    {:noreply, state}
  end

  defp accept(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    :ok =
      DynamicSupervisor.start_child(ExFTP.WorkerSupervisor, {ExFTP.Worker, client})
      |> case do
        {:ok, pid} ->
          :gen_tcp.controlling_process(client, pid)

        {:error, {:already_started, pid}} ->
          :gen_tcp.controlling_process(client, pid)

        other ->
          other
      end

    send(self(), :accept)
  end
end
