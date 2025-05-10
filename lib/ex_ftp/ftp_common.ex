defmodule ExFTP.Common do
  @moduledoc """
  This module contains shared functions between `ExFTP.Worker` and `ExFTP.Connector.Common`
  """

  require Logger

  @doc """
  Responds to the FTP client
  """
  def send_resp(code, msg, socket)
      when is_integer(code) and is_bitstring(msg) and is_map(socket) do
    response = "#{code} #{msg}\r\n"
    Logger.info("Sending FTP response:\t#{inspect(response)}")
    :gen_tcp.send(socket, response)
  end
end
