defmodule ExFTP.Connector.FileConnector do
  @moduledoc """
  An implementation of `ExFTP.StorageConnector` which serves content from local file storage.
  """
  @behaviour ExFTP.StorageConnector

  alias ExFTP.StorageConnector

  @impl StorageConnector
  @doc """
  Returns the current working directory
  """
  def get_working_directory(%{current_working_directory: cwd}), do: cwd

  @impl StorageConnector
  @doc """
  Whether a given path is an existing directory
  """
  def directory_exists?(path, _connector_state) do
    File.exists?(path) && File.dir?(path)
  end

  @impl StorageConnector
  @doc """
  Creates a directory, given a path
  """
  def make_directory(path, connector_state) do
    File.mkdir_p(path)
    |> case do
      :ok -> {:ok, connector_state}
      err -> err
    end
  end

  @impl StorageConnector
  @doc """
  Deletes a given directory
  """
  def delete_directory(path, connector_state) do
    rmrf_dir(path)
    |> case do
      {:ok, _} -> {:ok, connector_state}
      err -> err
    end
  end

  @impl StorageConnector
  @doc """
  Returns a list of `t:ExFTP.StorageConnector.content_info/0` representing each object in a given directory
  """
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

  @impl StorageConnector
  @doc """
  Returns a `t:ExFTP.StorageConnector.content_info/0` representing a given path
  """
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

  @impl StorageConnector
  @doc """
  Returns a stream to read the raw bytes of an object specified by a given path
  """
  def get_content(path, _connector_state) do
    File.read(path)
  end

  @impl StorageConnector
  @doc """
  Returns a writable stream that can be sent bytes that will be written to a given path
  """
  def open_write_stream(path, _connector_state) do
    {:ok, File.stream!(path)}
  end

  @impl StorageConnector
  @doc """
  Notification that the stream is finished writing and may be released and closed.
  """
  def close_write_stream(stream, _connector_state) do
    File.close(stream)
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
