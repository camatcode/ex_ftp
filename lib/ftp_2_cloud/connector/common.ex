defmodule FTP2Cloud.Connector.Common do
  @moduledoc false
  import FTP2Cloud.Common

  alias FTP2Cloud.PassiveSocket

  def pwd(connector, socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    :ok =
      if authenticator.authenticated?(authenticator_state) do
        send_resp(
          257,
          "\"#{connector.get_working_directory(connector_state)}\" is the current directory",
          socket
        )
      else
        send_resp(550, "Requested action not taken. File unavailable.", socket)
      end

    {:ok, connector_state}
  end

  def cwd(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_cwd(connector, path, socket, connector_state)
     end)}
  end

  def mkd(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_mkd(connector, path, socket, connector_state)
     end)}
  end

  def rmd(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_rmd(connector, path, socket, connector_state)
     end)}
  end

  def list(
        connector,
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state,
        include_hidden \\ false
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_list(connector, path, socket, pasv_socket, connector_state, include_hidden)
     end)}
  end

  def nlst(
        connector,
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state,
        include_hidden \\ false
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_nlst(connector, path, socket, pasv_socket, connector_state, include_hidden)
     end)}
  end

  defp authenticated_cwd(connector, path, socket, %{} = connector_state) do
    old_wd = connector.get_working_directory(connector_state)
    new_wd = change_prefix(old_wd, path)

    new_state =
      if connector.directory_exists?(new_wd, connector_state) do
        :ok = send_resp(250, "Directory changed successfully.", socket)
        connector_state |> Map.put(:current_working_directory, new_wd)
      else
        :ok = send_resp(550, "Failed to change directory. Does not exist.", socket)
        connector_state
      end

    new_state
  end

  defp authenticated_mkd(connector, path, socket, %{} = connector_state) do
    wd = connector.get_working_directory(connector_state)
    new_d = change_prefix(wd, path)

    if connector.directory_exists?(new_d, connector_state) do
      :ok = send_resp(521, "\"#{new_d}\" directory already exists", socket)
    else
      connector.make_directory(path, connector_state)
      |> case do
        {:ok, connector_state} ->
          :ok = send_resp(257, "\"#{new_d}\" directory created.", socket)
          connector_state

        _ ->
          :ok = send_resp(521, "Failed to make directory.", socket)
          connector_state
      end
    end
  end

  defp authenticated_rmd(connector, path, socket, %{} = connector_state) do
    wd = connector.get_working_directory(connector_state)
    rm_d = change_prefix(wd, path)

    connector.rm_directory(rm_d, connector_state)
    |> case do
      {:ok, connector_state} ->
        :ok = send_resp(250, "\"#{rm_d}\" directory removed.", socket)
        # kickout if you just RM'd the dir you're in
        new_working_dir = if wd == rm_d, do: change_prefix(wd, ".."), else: wd

        connector_state
        |> Map.put(:current_working_directory, new_working_dir)

      _ ->
        :ok = send_resp(550, "Failed to remove directory.", socket)
        connector_state
    end
  end

  @dummy_directories [
    %{
      file_name: ".",
      size: 4096,
      type: :directory,
      access: :read_write,
      modified_datetime: DateTime.now!("Etc/UTC")
    },
    %{
      file_name: "..",
      size: 4096,
      type: :directory,
      access: :read_write,
      modified_datetime: DateTime.now!("Etc/UTC")
    }
  ]

  defp authenticated_list(
         connector,
         path,
         socket,
         pasv_socket,
         %{} = connector_state,
         include_hidden
       ) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector.get_working_directory(connector_state), path)

    items =
      connector.get_directory_contents(wd, connector_state)
      |> case do
        {:ok, contents} ->
          if include_hidden do
            @dummy_directories ++ contents
          else
            contents
            |> Enum.reject(&hidden?/1)
          end
          |> Enum.sort_by(& &1.file_name)

        _ ->
          if include_hidden, do: @dummy_directories, else: []
      end
      |> Enum.map(&format_content(&1))

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

  defp authenticated_nlst(
         connector,
         path,
         socket,
         pasv_socket,
         %{} = connector_state,
         include_hidden
       ) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(connector.get_working_directory(connector_state), path)

    items =
      connector.get_directory_contents(wd, connector_state)
      |> case do
        {:ok, contents} ->
          if include_hidden do
            @dummy_directories ++ contents
          else
            contents
            |> Enum.reject(&hidden?/1)
          end
          |> Enum.sort_by(& &1.file_name)

        _ ->
          if include_hidden, do: @dummy_directories, else: []
      end
      |> Enum.map(&format_name(&1))

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

  defp hidden?(%{file_name: file_name}), do: String.starts_with?(file_name, ".")

  defp format_name(%{
         file_name: file_name,
         type: type
       }) do
    if type == :directory, do: file_name, else: file_name <> "/"
  end

  defp format_content(%{
         file_name: file_name,
         modified_datetime: date,
         size: size,
         access: access,
         type: type
       }) do
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

  defp wrap_auth(socket, %{} = connector_state, authenticator, %{} = authenticator_state, func) do
    if authenticator.authenticated?(authenticator_state) do
      func.()
    else
      :ok = send_resp(530, "Not logged in.", socket)
      connector_state
    end
  end
end
