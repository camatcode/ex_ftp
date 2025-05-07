defmodule FTP2Cloud.Common do
  @moduledoc false

  require Logger

  alias FTP2Cloud.PassiveSocket

  def send_resp(code, msg, socket) do
    response = "#{code} #{msg}\r\n"
    Logger.info("Sending FTP response:\t#{inspect(response)}")
    :gen_tcp.send(socket, response)
  end

  def quit(%{socket: socket} = state) do
    Logger.info("Shutting down. Client closed connection.")

    :ok = send_resp(221, "Closing connection.", socket)

    :gen_tcp.close(socket)

    pasv = state[:pasv_socket]

    if pasv && Process.alive?(pasv) do
      PassiveSocket.close(pasv)
    end

    {:stop, :normal, state}
  end
end
