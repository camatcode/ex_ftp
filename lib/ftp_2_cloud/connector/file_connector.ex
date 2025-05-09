defmodule FTP2Cloud.Connector.FileConnector do
  @moduledoc false
  @behaviour FTP2Cloud.StorageConnector

  import FTP2Cloud.Common

  alias FTP2Cloud.PassiveSocket
  alias FTP2Cloud.StorageConnector

  @impl StorageConnector
  def get_working_directory(%{current_working_directory: cwd}), do: cwd

  @impl StorageConnector
  def directory_exists?(path, _connector_state) do
    File.exists?(path) && File.dir?(path)
  end

  @impl StorageConnector
  def make_directory(path, connector_state) do
    File.mkdir_p(path)
    |> case do
      :ok -> {:ok, connector_state}
      err -> err
    end
  end

  @impl StorageConnector
  def rm_directory(path, connector_state) do
    rmrf_dir(path)
    |> case do
      {:ok, _} -> {:ok, connector_state}
      err -> err
    end
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

  def retr(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_retr(path, socket, pasv_socket, connector_state)
     end)}
  end

  def size(
        path,
        socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_size(path, socket, connector_state)
     end)}
  end

  def stor(
        path,
        socket,
        pasv_socket,
        %{} = connector_state,
        authenticator,
        %{} = authenticator_state
      ) do
    {:ok,
     wrap_auth(socket, connector_state, authenticator, authenticator_state, fn ->
       authenticated_stor(path, socket, pasv_socket, connector_state)
     end)}
  end

  defp authenticated_list(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Here comes the directory listing.", socket)

    wd = change_prefix(get_working_directory(connector_state), path)

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

    wd = change_prefix(get_working_directory(connector_state), path)

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

    wd = change_prefix(get_working_directory(connector_state), path)

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

    wd = change_prefix(get_working_directory(connector_state), path)

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

  defp authenticated_retr(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Opening BINARY mode data connection for #{path}", socket)
    w_path = change_prefix(get_working_directory(connector_state), path)

    if File.exists?(w_path) && File.regular?(w_path) do
      bytes = File.read!(path)
      PassiveSocket.write(pasv_socket, bytes, close_after_write: true)
      :ok = send_resp(226, "Transfer complete.", socket)
    else
      :ok = send_resp(451, "File not found.", socket)
    end

    connector_state
  end

  def authenticated_size(path, socket, %{} = connector_state) do
    w_path = change_prefix(get_working_directory(connector_state), path)

    if File.exists?(w_path) do
      %{size: size} = File.lstat!(w_path)
      :ok = send_resp(213, "#{size}", socket)
    else
      :ok = send_resp(550, "Could not get file size.", socket)
    end

    connector_state
  end

  defp authenticated_stor(path, socket, pasv_socket, %{} = connector_state) do
    :ok = send_resp(150, "Ok to send data.", socket)
    w_path = change_prefix(get_working_directory(connector_state), path)

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
          File.close(fs)
        end
      end,
      fs: File.stream!(w_path),
      chunk_size: 5 * 1024 * 1024
    )

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

  defp wrap_auth(socket, %{} = connector_state, authenticator, %{} = authenticator_state, func) do
    if authenticator.authenticated?(authenticator_state) do
      func.()
    else
      :ok = send_resp(530, "Not logged in.", socket)
      connector_state
    end
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
