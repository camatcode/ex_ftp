# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3Connector do
  @moduledoc false

  @behaviour ExFTP.StorageConnector

  import ExFTP.Storage.Common
  import ExFTP.Common

  alias ExFTP.StorageConnector
  alias ExFTP.Storage.S3ConnectorConfig

  @impl StorageConnector
  def get_working_directory(%{current_working_directory: cwd} = _connector_state), do: cwd

  @impl StorageConnector
  def directory_exists?(path, connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) |> IO.inspect(label: :config) do
      virtual_directory?(path, connector_state) || s3_prefix_exists?(config, path)
    end
  end

  defp virtual_directory?(path, connector_state) do
    current_v_dirs = Map.get(connector_state, :virtual_directories, ["/"])
    Enum.member?(current_v_dirs, path)
  end

  @impl StorageConnector
  def make_directory(path, connector_state) do
    parent_dirs =
      path
      |> Path.dirname()
      |> Path.split()

    dirs = parent_dirs ++ [path]

    current_v_dirs = Map.get(connector_state, :virtual_directories, ["/"])

    new_v_dirs =
      (current_v_dirs ++ dirs)
      |> Enum.uniq()

    connector_state = Map.put(connector_state, :virtual_directories, new_v_dirs)
    {:ok, connector_state}
  end

  @impl StorageConnector
  def delete_directory(path, connector_state) do
    if directory_exists?(path, connector_state) do
      with {:ok, config} <- validate_config(S3ConnectorConfig) do
        delete_s3_prefix(config, path)
      end
    end

    current_v_dirs =
      Map.get(connector_state, :virtual_directories, ["/"])

    new_v_dirs =
      ((current_v_dirs -- [path]) ++ ["/"])
      |> Enum.uniq()

    connector_state = Map.put(connector_state, :virtual_directories, new_v_dirs)
    {:ok, connector_state}
  end

  @impl StorageConnector
  def get_directory_contents(path, %{} = connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      contents = s3_get_prefix_contents(config, path, connector_state)
      {:ok, contents}
    end
  end

  @impl StorageConnector
  def get_content(path, _connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      bucket = get_bucket(config, path)
      prefix = get_prefix(config, bucket, path)

      stream =
        bucket
        |> ExAws.S3.download_file(prefix, :memory, chunk_size: 5 * 1024 * 1024)
        |> ExAws.stream!()

      {:ok, stream}
    end
  end

  @file_action_aborted 552
  @closing_connection_success 226

  @impl StorageConnector
  def get_write_func(path, socket, _connector_state, _opts \\ []) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      bucket = get_bucket(config, path)
      prefix = get_prefix(config, bucket, path)

      fn stream, opts ->
        try do
          chunk_stream(stream, opts)
          |> ExAws.S3.upload(bucket, prefix)
          |> ExAws.request!()

          send_resp(@closing_connection_success, "Transfer Complete.", socket)
        rescue
          _ -> send_resp(@file_action_aborted, "Failed to transfer.", socket)
        after
          nil
        end
      end
    end
  end

  @impl StorageConnector
  def get_content_info(path, connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      s3_get_prefix_contents(config, path, connector_state)
      |> case do
        [content | _] -> {:ok, content}
        _ -> {:error, "Could not get content info"}
      end
    end
  end

  defp s3_get_prefix_contents(%{} = config, path, connector_state) do
    bucket = get_bucket(config, path)
    prefix = get_prefix(config, bucket, path)

    objects =
      if bucket do
        # yes I know I'm forcing evaluation
        # TODO: figure out how to append to a stream
        # Its probably a stream.resource() wrapper
        ExAws.S3.list_objects(bucket, prefix: prefix, delimiter: "/", stream_prefixes: true)
        |> ExAws.stream!()
        |> Stream.map(fn thing ->
          to_content_info(thing)
        end)
        |> Enum.into([])
      else
        []
      end

    current_v_dirs =
      Map.get(connector_state, :virtual_directories, ["/"])

    objects_to_append =
      current_v_dirs
      |> Enum.filter(fn v_dir ->
        starts_with = String.starts_with?(v_dir, path)
        direct_child = Enum.count(Path.split(v_dir)) == Enum.count(Path.split(path)) + 1
        starts_with && direct_child
      end)
      |> Enum.map(fn v_dir ->
        to_content_info(%{prefix: Path.basename(v_dir)})
      end)

    objects ++ objects_to_append
  end

  defp to_content_info(%{prefix: prefix}) do
    %{
      file_name: prefix,
      modified_datetime: DateTime.from_unix!(0),
      size: 4096,
      access: :read_write,
      type: :directory
    }
  end

  defp to_content_info(%{key: filename, last_modified: last_mod_str}) do
    {:ok, modified_datetime, _} = DateTime.from_iso8601(last_mod_str)

    %{
      file_name: filename,
      modified_datetime: modified_datetime,
      size: 4096,
      access: :read_write,
      type: :file
    }
  end

  defp delete_s3_prefix(config, path) do
    bucket = get_bucket(config, path)
    prefix = get_prefix(config, bucket, path)

    stream =
      ExAws.S3.list_objects(bucket, prefix: prefix)
      |> ExAws.stream!()
      |> Stream.map(& &1.key)

    ExAws.S3.delete_all_objects(bucket, stream)
    |> ExAws.request()
  end

  defp s3_prefix_exists?(config, path) do
    bucket = get_bucket(config, path) |> IO.inspect(label: :bucket)
    prefix = get_prefix(config, bucket, path) |> IO.inspect(label: :prefix)

    if bucket do
      bucket_exists?(bucket) && prefix_exists?(bucket, prefix)
    else
      prefix_exists?(bucket, prefix)
    end
  end

  # / == s3://storage_bucket/
  defp get_bucket(%{storage_bucket: storage_bucket} = _config, _path)
       when not is_nil(storage_bucket),
       do: storage_bucket

  # / == list buckets
  defp get_bucket(%{storage_bucket: nil} = _config, "/" = _path), do: nil

  # /path == s3://path/
  defp get_bucket(%{storage_bucket: nil} = _config, path) do
    ["/", bucket | _] = Path.split(path)
    bucket
  end

  # / == s3://storage_bucket/
  defp get_prefix(%{storage_bucket: storage_bucket} = _config, _bucket, "/" = _path)
       when not is_nil(storage_bucket) do
    nil
  end

  # /path == s3://path
  defp get_prefix(%{storage_bucket: nil} = _config, bucket, path) do
    prefix =
      path
      |> String.replace("/#{bucket}", "")
      |> String.replace(~r/^\//, "")

    if "" == prefix, do: nil, else: prefix
  end

  defp get_prefix(_config, _bucket, path) do
    prefix =
      path
      |> String.replace(~r/^\//, "")

    if "" == prefix, do: nil, else: prefix
  end

  defp bucket_exists?(nil), do: false

  defp bucket_exists?(bucket) do
    ExAws.S3.head_bucket(bucket)
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> true
      _ -> false
    end
  end

  defp prefix_exists?(bucket, nil = _prefix)
       when not is_nil(bucket),
       do: bucket_exists?(bucket)

  defp prefix_exists?(bucket, prefix) do
    empty? =
      ExAws.S3.list_objects(bucket, delimiter: "/", prefix: prefix)
      |> ExAws.stream!()
      |> Enum.take(1)
      |> Enum.empty?()

    !empty?
  end
end
