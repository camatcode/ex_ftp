defmodule FTP2Cloud.Auth.PassthroughAuth do
  @moduledoc false

  import FTP2Cloud.Common

  def user(username, socket, %{} = authenticator_state) do
    :ok = send_resp(331, "User name okay, need password.", socket)
    new_state = authenticator_state |> Map.put(:username, username)
    {:ok, new_state}
  end

  def pass(_password, socket, %{username: "root"}) do
    :ok =
      send_resp(
        530,
        "Authentication failed.",
        socket
      )

    new_state = %{}
    {:ok, new_state}
  end

  def pass(_password, socket, %{username: username} = authenticator_state) do
    :ok = send_resp(230, "Welcome #{username}.", socket)
    new_state = authenticator_state |> Map.put(:authenticated, true)
    {:ok, new_state}
  end

  def is_authenticated?(%{authenticated: authenticated}), do: authenticated
end
