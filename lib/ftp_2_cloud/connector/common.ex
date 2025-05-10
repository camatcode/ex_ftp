defmodule FTP2Cloud.Connector.Common do
  @moduledoc false
  import FTP2Cloud.Common

  alias FTP2Cloud.PassiveSocket

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

  def pwd(connector, socket, %{} = connector_state, authenticator, %{} = authenticator_state) do
    with :ok <- check_auth(socket, authenticator, authenticator_state) do
      send_resp(
        257,
        "\"#{connector.get_working_directory(connector_state)}\" is the current directory",
        socket
      )
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
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok -> cwd_impl(connector, path, socket, connector_state)
      _ -> connector_state
    end
    |> wrap_OK()
  end

  def mkd(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok -> mkd_impl(connector, path, socket, connector_state)
      _ -> connector_state
    end
    |> wrap_OK()
  end

  def rmd(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok -> rmd_impl(connector, path, socket, connector_state)
      _ -> connector_state
    end
    |> wrap_OK()
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
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok ->
        list_impl(
          connector,
          path,
          socket,
          pasv_socket,
          connector_state,
          include_hidden
        )

      _ ->
        connector_state
    end
    |> wrap_OK()
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
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok ->
        nlst_impl(
          connector,
          path,
          socket,
          pasv_socket,
          connector_state,
          include_hidden
        )

      _ ->
        connector_state
    end
    |> wrap_OK()
  end

  def retr(
        connector,
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok ->
        retr_impl(connector, path, socket, pasv_socket, connector_state)

      _ ->
        connector_state
    end
    |> wrap_OK()
  end

  def size(
        connector,
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok ->
        size_impl(connector, path, socket, connector_state)

      _ ->
        connector_state
    end
    |> wrap_OK()
  end

  def stor(
        connector,
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    check_auth(socket, authenticator, authenticator_state)
    |> case do
      :ok ->
        stor_impl(connector, path, socket, pasv_socket, connector_state)

      _ ->
        connector_state
    end
    |> wrap_OK()
  end

  def wrap_OK({:ok, thing}), do: {:ok, thing}
  def wrap_OK(thing), do: {:ok, thing}

  defp cwd_impl(connector, path, socket, %{} = connector_state) do
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

  defp mkd_impl(connector, path, socket, %{} = connector_state) do
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

  defp rmd_impl(connector, path, socket, %{} = connector_state) do
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

  defp list_impl(
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

  defp nlst_impl(
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

  defp retr_impl(connector, path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Opening BINARY mode data connection for #{path}", socket)
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.get_content(w_path, connector_state)
    |> case do
      {:ok, stream} ->
        PassiveSocket.write(pasv_socket, stream, close_after_write: true)
        :ok = send_resp(226, "Transfer complete.", socket)

      _ ->
        :ok = send_resp(451, "File not found.", socket)
        PassiveSocket.close(pasv_socket)
    end

    connector_state
  end

  defp size_impl(connector, path, socket, %{} = connector_state) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.get_content_info(w_path, connector_state)
    |> case do
      {:ok, %{size: size}} -> :ok = send_resp(213, "#{size}", socket)
      _ -> :ok = send_resp(550, "Could not get file size.", socket)
    end

    connector_state
  end

  defp stor_impl(connector, path, socket, pasv_socket, %{} = connector_state) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.open_write_stream(w_path, connector_state)
    |> case do
      {:ok, stream} ->
        :ok = send_resp(150, "Ok to send data.", socket)

        PassiveSocket.read(
          pasv_socket,
          fn stream, opts ->
            fs = opts[:fs]

            try do
              _fs =
                chunk_stream(stream, opts)
                |> Enum.into(fs)

              :ok = send_resp(226, "Transfer Complete.", socket)
            rescue
              _ -> :ok = send_resp(552, "Failed to transfer.", socket)
            after
              connector.close_write_stream(fs, connector_state)
            end
          end,
          fs: stream,
          chunk_size: 5 * 1024 * 1024
        )

      _ ->
        :ok = send_resp(552, "Failed to transfer.", socket)
    end

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

  defp check_auth(socket, authenticator, %{} = authenticator_state) do
    if authenticator.authenticated?(authenticator_state) do
      :ok
    else
      :ok = send_resp(530, "Not logged in.", socket)
      :err
    end
  end
end
