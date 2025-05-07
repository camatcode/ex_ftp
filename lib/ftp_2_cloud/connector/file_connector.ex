defmodule FTP2Cloud.Connector.FileConnector do
  @moduledoc false

  import FTP2Cloud.Common

  def pwd(socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    :ok =
      if authenticator.is_authenticated?(authenticator_state) do
        send_resp(257, "\"#{connector_state[:prefix] || "/"}\" is the current directory", socket)
      else
        send_resp(550, "Requested action not taken. File unavailable.", socket)
      end
  end
end
