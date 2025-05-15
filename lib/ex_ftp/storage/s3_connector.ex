# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3Connector do
  @moduledoc false
  import ExFTP.Storage.Common

  alias ExFTP.Storage.S3ConnectorConfig

  def get_working_directory(%{current_working_directory: cwd} = _connector_state), do: cwd

  def directory_exists?(path, _connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      s3_prefix_exists?(config, path)
    end
  end

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

  def get_directory_contents(path, %{} = connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      s3_get_prefix_contents(config, path, connector_state)
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
    bucket = get_bucket(config, path)
    prefix = get_prefix(config, bucket, path)

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
