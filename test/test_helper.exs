ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start()

defmodule ExFTP.TestHelper do
  @moduledoc false

  def send(socket, cmd, args \\ []) do
    cmd = String.trim(cmd)

    arg_str =
      args
      |> Enum.map_join(" ", fn arg -> String.trim(arg) end)

    :ok = :gen_tcp.send(socket, "#{cmd} #{arg_str}\r\n")
  end

  def expect_recv(socket, code, msg_start) do
    match = "#{code} #{msg_start}"
    {:ok, ^match <> _} = :gen_tcp.recv(socket, 0, 5_000)
  end
end
