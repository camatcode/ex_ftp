ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

defmodule ExFTP.TestHelper do
  @moduledoc false

  use ExUnit.Case

  import Bitwise

  def send(socket, cmd, args \\ []) do
    cmd = String.trim(cmd)

    arg_str =
      args
      |> Enum.map_join(" ", fn arg -> String.trim(arg) end)

    cmd = "#{cmd} #{arg_str}" |> String.trim()

    :ok = :gen_tcp.send(socket, "#{cmd}\r\n")
    socket
  end

  def expect_recv(socket, code, msg_start \\ "") do
    match = "#{code} #{msg_start}"
    {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 20_000)
    socket
  end

  def flush_recv(socket) do
    :gen_tcp.recv(socket, 0, 20_000)
    socket
  end

  def send_and_expect(socket, cmd, args, code, msg_start \\ "") do
    send(socket, cmd, args)
    expect_recv(socket, code, msg_start)
    socket
  end

  def read_fully(socket, data \\ <<>>) do
    case :gen_tcp.recv(socket, 0, 20_000) do
      {:ok, resp} -> read_fully(socket, data <> resp)
      {:error, :closed} -> {:ok, data}
    end
  end

  def setup_pasv_connection(%{socket: socket} = state) do
    send(socket, "PASV", [])

    assert {:ok, "227 Entering Passive Mode " <> ip_port_string} =
             :gen_tcp.recv(socket, 0, 20_000)

    [_, ip_port_string] = Regex.run(~r/\((.*)\)/, ip_port_string)

    assert [o1, o2, o3, o4, ip1, ip2] =
             ip_port_string
             |> String.trim()
             |> String.split(",")
             |> Enum.map(&String.to_integer/1)

    ip = {o1, o2, o3, o4}
    port = (ip1 <<< 8) + (255 &&& ip2)

    assert {:ok, pasv_socket} = :gen_tcp.connect(ip, port, [:binary, active: false])

    on_exit(:close_pasv_socket, fn -> :gen_tcp.close(pasv_socket) end)

    state
    |> Map.put(:pasv_socket, pasv_socket)
  end

  def close_pasv(pasv), do: :gen_tcp.close(pasv)

  def get_socket do
    port = Application.get_env(:ex_ftp, :ftp_port)
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
    {:ok, _} = :gen_tcp.recv(socket, 0, 10_000)

    on_exit(:close_socket, fn -> :gen_tcp.close(socket) end)
    socket
  end
end
