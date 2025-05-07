defmodule FTP2Cloud.Connector.FileConnector do
  @moduledoc false

  import FTP2Cloud.Common

  def pwd(socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    :ok =
      if authenticator.is_authenticated?(authenticator_state) do
        send_resp(
          257,
          "\"#{connector_state[:current_working_directory]}\" is the current directory",
          socket
        )
      else
        send_resp(550, "Requested action not taken. File unavailable.", socket)
      end

    {:ok, connector_state}
  end

  def cwd(path, socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_cwd(path, socket, connector_state)
     end)}
  end

  def mkd(path, socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_mkd(path, socket, connector_state)
     end)}
  end

  def rmd(path, socket, %{} = connector_state, authenticator, authenticator_state = %{}) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_rmd(path, socket, connector_state)
     end)}
  end

  defp wrap_auth(socket, %{} = connector_state, authenticator, authenticator_state = %{}, func) do
    if authenticator.is_authenticated?(authenticator_state) do
      func.()
    else
      :ok = send_resp(530, "Not logged in.", socket)
      connector_state
    end
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

  defp authenticated_mkd(path, socket, %{} = connector_state) do
    wd = connector_state[:current_working_directory]
    new_d = change_prefix(wd, path)

    if File.exists?(new_d) do
      :ok = send_resp(521, "\"#{new_d}\" directory already exists", socket)
    else
      File.mkdir_p(new_d)
      |> case do
        :ok -> :ok = send_resp(257, "\"#{new_d}\" directory created.", socket)
        _ -> :ok = send_resp(521, "Failed to make directory.", socket)
      end
    end

    connector_state
  end

  defp authenticated_rmd(path, socket, %{} = connector_state) do
    wd = connector_state[:current_working_directory]
    rm_d = change_prefix(wd, path)

    if File.exists?(rm_d) && rm_d != "/" do
      File.rm_rf(rm_d)
      |> case do
        {:ok, _} ->
          :ok = send_resp(250, "\"#{rm_d}\" directory removed.", socket)
          if wd == rm_d, do: change_prefix(wd, "..")

        _ ->
          :ok = send_resp(550, "Failed to remove directory.", socket)
      end
    else
      :ok = send_resp(250, "\"#{rm_d}\" directory removed.", socket)
    end

    # kickout if you just RM'd the dir you're in
    new_working_dir = if wd == rm_d, do: change_prefix(wd, ".."), else: wd

    connector_state
    |> Map.put(:current_working_directory, new_working_dir)
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
