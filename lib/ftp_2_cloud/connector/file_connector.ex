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

  @impl StorageConnector
  def get_directory_contents(path, connector_state) do
    File.ls(path)
    |> case do
      {:ok, files} ->
        contents =
          Enum.map(files, fn file_name ->
            {:ok, content_info} = get_content_info(Path.join(path, file_name), connector_state)
            content_info
          end)

        {:ok, contents}

      err ->
        err
    end
  end

  def get_content_info(path, _connector_state) do
    File.lstat(path)
    |> case do
      {:ok,
       %{
         size: size,
         mtime: {{year, month, day}, {hour, minute, second}},
         access: access,
         type: type
       }} ->
        file_name =
          if type == :symlink do
            {:ok, target} = :file.read_link(path)
            "#{Path.basename(path)} -> #{target}"
          else
            Path.basename(path)
          end

        date = DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second))

        {:ok,
         %{
           file_name: file_name,
           modified_datetime: date,
           size: size,
           access: access,
           type: type
         }}

      err ->
        err
    end
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
