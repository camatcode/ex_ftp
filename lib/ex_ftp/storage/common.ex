defmodule ExFTP.Storage.Common do
  @moduledoc false
  import ExFTP.Common

  alias ExFTP.PassiveSocket

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

  @directory_action_ok 257
  @directory_action_not_taken 521
  @file_action_ok 250
  @file_action_not_taken 550
  @file_status_ok 213
  @opening_data_connection 150
  @closing_connection_success 226
  @action_aborted 451
  @file_action_aborted 552

  def pwd(%{
        storage_connector: connector,
        socket: socket,
        connector_state: connector_state
      }) do
    :ok =
      send_resp(
        @directory_action_ok,
        "\"#{connector.get_working_directory(connector_state)}\" is the current directory",
        socket
      )

    connector_state
  end

  def cwd(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        connector_state: connector_state
      }) do
    old_wd = connector.get_working_directory(connector_state)
    new_wd = change_prefix(old_wd, path)

    new_state =
      if connector.directory_exists?(new_wd, connector_state) do
        :ok = send_resp(@file_action_ok, "Directory changed successfully.", socket)
        connector_state |> Map.put(:current_working_directory, new_wd)
      else
        :ok =
          send_resp(@file_action_not_taken, "Failed to change directory. Does not exist.", socket)

        connector_state
      end

    new_state
  end

  def mkd(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        connector_state: connector_state
      }) do
    wd = connector.get_working_directory(connector_state)
    new_d = change_prefix(wd, path)

    if connector.directory_exists?(new_d, connector_state) do
      :ok =
        send_resp(@directory_action_not_taken, "\"#{new_d}\" directory already exists", socket)
    else
      connector.make_directory(path, connector_state)
      |> case do
        {:ok, connector_state} ->
          :ok = send_resp(@directory_action_ok, "\"#{new_d}\" directory created.", socket)
          connector_state

        _ ->
          :ok = send_resp(@directory_action_not_taken, "Failed to make directory.", socket)
          connector_state
      end
    end
  end

  def rmd(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        connector_state: connector_state
      }) do
    wd = connector.get_working_directory(connector_state)
    rm_d = change_prefix(wd, path)

    connector.delete_directory(rm_d, connector_state)
    |> case do
      {:ok, connector_state} ->
        :ok = send_resp(@file_action_ok, "\"#{rm_d}\" directory removed.", socket)
        # kickout if you just RM'd the dir you're in
        new_working_dir = if wd == rm_d, do: change_prefix(wd, ".."), else: wd

        connector_state
        |> Map.put(:current_working_directory, new_working_dir)

      _ ->
        :ok = send_resp(@file_action_not_taken, "Failed to remove directory.", socket)
        connector_state
    end
  end

  def list(%{
        socket: socket,
        storage_connector: connector,
        connector_state: connector_state,
        pasv: pasv,
        path: path,
        include_hidden: include_hidden
      }) do
    :ok = send_resp(@opening_data_connection, "Here comes the directory listing.", socket)

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
      PassiveSocket.write(pasv, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv, &1, close_after_write: false))

      PassiveSocket.close(pasv)
    end

    :ok = send_resp(@closing_connection_success, "Directory send OK.", socket)
    connector_state
  end

  def nlst(%{
        socket: socket,
        storage_connector: connector,
        connector_state: connector_state,
        pasv: pasv,
        path: path,
        include_hidden: include_hidden
      }) do
    :ok = send_resp(@opening_data_connection, "Here comes the directory listing.", socket)

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
      PassiveSocket.write(pasv, "", close_after_write: true)
    else
      :ok =
        items
        |> Enum.each(&PassiveSocket.write(pasv, &1, close_after_write: false))

      PassiveSocket.close(pasv)
    end

    :ok = send_resp(@closing_connection_success, "Directory send OK.", socket)
    connector_state
  end

  def retr(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        pasv: pasv,
        connector_state: connector_state
      }) do
    :ok =
      send_resp(
        @opening_data_connection,
        "Opening BINARY mode data connection for #{path}",
        socket
      )

    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.get_content(w_path, connector_state)
    |> case do
      {:ok, stream} ->
        PassiveSocket.write(pasv, stream, close_after_write: true)
        :ok = send_resp(@closing_connection_success, "Transfer complete.", socket)

      _ ->
        :ok = send_resp(@action_aborted, "File not found.", socket)
        PassiveSocket.close(pasv)
    end

    connector_state
  end

  def size(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        connector_state: connector_state
      }) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.get_content_info(w_path, connector_state)
    |> case do
      {:ok, %{size: size}} -> :ok = send_resp(@file_status_ok, "#{size}", socket)
      _ -> :ok = send_resp(@file_action_not_taken, "Could not get file size.", socket)
    end

    connector_state
  end

  def stor(%{
        storage_connector: connector,
        path: path,
        socket: socket,
        pasv: pasv,
        connector_state: connector_state
      }) do
    w_path = change_prefix(connector.get_working_directory(connector_state), path)

    connector.open_write_stream(w_path, connector_state)
    |> case do
      {:ok, stream} ->
        :ok = send_resp(@opening_data_connection, "Ok to send data.", socket)

        PassiveSocket.read(
          pasv,
          fn stream, opts ->
            fs = opts[:fs]

            try do
              _fs =
                chunk_stream(stream, opts)
                |> Enum.into(fs)

              :ok = send_resp(@closing_connection_success, "Transfer Complete.", socket)
            rescue
              _ -> :ok = send_resp(@file_action_aborted, "Failed to transfer.", socket)
            after
              connector.close_write_stream(fs, connector_state)
            end
          end,
          fs: stream,
          chunk_size: 5 * 1024 * 1024
        )

      _ ->
        :ok = send_resp(@file_action_aborted, "Failed to transfer.", socket)
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

  def chunk_stream(stream, opts \\ []) do
    opts = Keyword.merge([chunk_size: 5 * 1024 * 1024], opts)

    Stream.chunk_while(
      stream,
      <<>>,
      fn data, chunk ->
        chunk = chunk <> data

        if byte_size(chunk) >= opts[:chunk_size] do
          {:cont, chunk, <<>>}
        else
          {:cont, chunk}
        end
      end,
      fn
        <<>> -> {:cont, []}
        chunk -> {:cont, chunk, []}
      end
    )
  end
end
