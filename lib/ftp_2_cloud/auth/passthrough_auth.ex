defmodule FTP2Cloud.Auth.PassthroughAuth do
  @moduledoc false

  import FTP2Cloud.Common

  def user(_username, %{socket: socket}) do
    send_resp(331, "User name okay, need password.", socket)
  end

  def pass(_password, %{socket: socket, username: "root"}) do
    send_resp(
      530,
      "Authentication failed.",
      socket
    )
  end

  def pass(_password, %{socket: socket, username: username}) do
    send_resp(230, "Welcome #{username}.", socket)
  end
end
