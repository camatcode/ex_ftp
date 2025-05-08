defmodule FTP2Cloud.Connector.FileConnector do
  @moduledoc false

  import FTP2Cloud.Common

  alias FTP2Cloud.PassiveSocket

  def pwd(socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    :ok =
      if authenticator.authenticated?(authenticator_state) do
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

  def cwd(path, socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_cwd(path, socket, connector_state)
     end)}
  end

  def mkd(path, socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_mkd(path, socket, connector_state)
     end)}
  end

  def rmd(path, socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_rmd(path, socket, connector_state)
     end)}
  end

  def list(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_list(path, socket, pasv_socket, connector_state)
     end)}
  end

  def list_a(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_list_a(path, socket, pasv_socket, connector_state)
     end)}
  end

  def nlst(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_nlst(path, socket, pasv_socket, connector_state)
     end)}
  end

  def nlst_a(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_nlst_a(path, socket, pasv_socket, connector_state)
     end)}
  end

  defp wrap_auth(socket, %{} = connector_state, authenticator, %{} = authenticator_state, func) do
    if authenticator.authenticated?(authenticator_state) do
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

    rmrf_dir(rm_d)
    |> case do
      {:ok, _} ->
        :ok = send_resp(250, "\"#{rm_d}\" directory removed.", socket)
        if wd == rm_d, do: change_prefix(wd, "..")

      _ ->
        :ok = send_resp(550, "Failed to remove directory.", socket)
    end

    # kickout if you just RM'd the dir you're in
    new_working_dir = if wd == rm_d, do: change_prefix(wd, ".."), else: wd

    connector_state
    |> Map.put(:current_working_directory, new_working_dir)
  end

  defp authenticated_list(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector_state[:current_working_directory], path)

    items =
      File.ls(wd)
      |> case do
        {:ok, files} ->
          files
          |> Enum.reject(&String.starts_with?(&1, "."))
          |> Enum.sort()

        _ ->
          []
      end
      |> Enum.map(&format_list_item(&1, wd))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv_socket, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv_socket, &1, close_after_write: false))

      PassiveSocket.close(pasv_socket)
    end

    :ok = send_resp(226, "Directory send OK.", socket)
    connector_state
  end

  defp authenticated_list_a(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector_state[:current_working_directory], path)

    items =
      File.ls(wd)
      |> case do
        {:ok, files} -> ([".", ".."] ++ files) |> Enum.sort()
        _ -> [".", ".."]
      end
      |> Enum.map(&format_list_item(&1, wd))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv_socket, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv_socket, &1, close_after_write: false))

      PassiveSocket.close(pasv_socket)
    end

    :ok = send_resp(226, "Directory send OK.", socket)
    connector_state
  end

  defp authenticated_nlst(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector_state[:current_working_directory], path)

    items =
      File.ls(wd)
      |> case do
        {:ok, files} ->
          files
          |> Enum.reject(&String.starts_with?(&1, "."))
          |> Enum.sort()

        _ ->
          []
      end
      |> Enum.map(&format_name_item(&1, wd))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv_socket, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv_socket, &1, close_after_write: false))

      PassiveSocket.close(pasv_socket)
    end

    :ok = send_resp(226, "Directory send OK.", socket)
    connector_state
  end

  defp authenticated_nlst_a(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector_state[:current_working_directory], path)

    items =
      File.ls(wd)
      |> case do
        {:ok, files} ->
          files
          |> Enum.sort()

        _ ->
          []
      end
      |> Enum.map(&format_name_item(&1, wd))

    if Enum.empty?(items) do
      PassiveSocket.write(pasv_socket, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv_socket, &1, close_after_write: false))

      PassiveSocket.close(pasv_socket)
    end

    :ok = send_resp(226, "Directory send OK.", socket)
    connector_state
  end

  defp format_list_item(file_name, wd) do
    Path.join(wd, file_name)
    |> File.lstat!(time: :local)
    |> format_file_stat(file_name, wd)
  end

  defp format_name_item(file_name, wd) do
    path = Path.join(wd, file_name)
    if File.dir?(path), do: Path.basename(path) <> "/", else: Path.basename(path)
  end

  defp format_file_stat(
         %File.Stat{
           size: size,
           mtime: {{year, month, day}, {hour, minute, second}},
           access: access,
           type: type
         },
         file_name,
         directory
       ) do
    file_name =
      if type == :symlink do
        {:ok, target} = :file.read_link(Path.join(directory, file_name))
        "#{file_name} -> #{target}"
      else
        file_name
      end

    type =
      type
      |> case do
        :directory -> "d"
        :symlink -> "l"
        _ -> "-"
      end

    access =
      access
      |> case do
        :read -> "r--"
        :write -> "-w-"
        :read_write -> "rw-"
        _ -> "---"
      end

    size = to_string(size) |> String.pad_leading(16)

    date =
      DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second))
      |> Calendar.strftime("%b %d  %Y")

    owner = " 0"
    group = "        0"
    unknown_val = "1" |> String.pad_leading(5)
    permissions = "#{type}#{access}r--r--"

    "#{permissions}#{unknown_val}#{owner}#{group}#{size} #{date} #{file_name}"
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

  defp rmrf_dir("/"), do: {:ok, nil}

  defp rmrf_dir(dir) do
    if File.exists?(dir) && File.dir?(dir) do
      File.rm_rf(dir)
    else
      {:ok, nil}
    end
  end
end
