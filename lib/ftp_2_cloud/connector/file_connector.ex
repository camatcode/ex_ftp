defmodule FTP2Cloud.Connector.FileConnector do
  @moduledoc false

  import FTP2Cloud.Common

  def pwd(socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    :ok =
      if authenticator.is_authenticated?(authenticator_state) do
        send_resp(
          257,
          "\"#{connector_state[:current_working_directory] || "/"}\" is the current directory",
          socket
        )
      else
        send_resp(550, "Requested action not taken. File unavailable.", socket)
      end

    {:ok, connector_state}
  end

  def cwd(path, socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    new_state =
      if authenticator.is_authenticated?(authenticator_state) do
        authenticated_cwd(path, socket, connector_state)
      else
        :ok = send_resp(530, "Not logged in.", socket)
        connector_state
      end

    {:ok, new_state}
  end

  defp authenticated_cwd(path, socket, %{} = connector_state) do
    old_wd = connector_state[:current_working_directory]
    new_wd = change_prefix(old_wd, path)

    new_state =
      if File.exists?(new_wd) do
        :ok = send_resp(250, "Directory changed successfully.", socket)
        connector_state |> Map.put(:current_working_directory, new_wd)
      else
        :ok = send_resp(550, "Failed to change directory. Does not exist.", socket)
        connector_state
      end

    new_state
  end

  defp change_prefix(nil, path), do: change_prefix("/", path)

  defp change_prefix(current_prefix, path) do
    cond do
      String.starts_with?(path, "/") ->
        Path.expand(path)

      String.starts_with?(path, "~") ->
        String.replace(path, "~", "/") |> Path.expand()

      true ->
        Path.join(current_prefix, path)
        |> Path.expand()
    end
  end
end
