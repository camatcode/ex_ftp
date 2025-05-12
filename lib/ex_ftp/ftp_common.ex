# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Common do
  @moduledoc """
  This module contains shared functions between `ExFTP.Worker` and `ExFTP.Storage.Common`
  """

  require Logger

  @doc """
  Responds to the FTP client
  """
  def send_resp(code, msg, socket) when is_integer(code) and is_bitstring(msg) do
    response = "#{code} #{msg}\r\n"
    Logger.info("Sending FTP response:\t#{inspect(response)}")
    :ok = :gen_tcp.send(socket, response)
  end
end
