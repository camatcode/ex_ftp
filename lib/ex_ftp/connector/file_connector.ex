defmodule ExFTP.Connector.FileConnector do
  @moduledoc false
  @behaviour ExFTP.StorageConnector

  alias ExFTP.StorageConnector

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
  def delete_directory(path, connector_state) do
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

  @impl StorageConnector
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
  def get_content(path, _connector_state) do
    File.read(path)
  end

  @impl StorageConnector
  def open_write_stream(path, _connector_state) do
    {:ok, File.stream!(path)}
  end

  @impl StorageConnector
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
