# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3Connector do
  @moduledoc """
  When **storage_connector** is `ExFTP.Storage.S3Connector`, this connector will use any S3-compatible storage provider.

  Underneath the hood, ex_ftp is using `ExAws.S3`, so you'll need that configured properly.
  """

  @behaviour ExFTP.StorageConnector

  import ExFTP.Common
  import ExFTP.Storage.Common

  alias ExFTP.Storage.S3ConnectorConfig
  alias ExFTP.StorageConnector

  @impl StorageConnector
  def get_working_directory(%{current_working_directory: cwd} = _connector_state) do
    cwd
  end

  defp clean_path(path) do
    path = Path.join(path, "") <> "/"
    path = "/" <> path
    String.replace(path, "//", "/")
  end

  defp virtual_directory?(config, path, connector_state) do
    path = clean_path(path)

    config
    |> get_virtual_directories(connector_state)
    |> Enum.member?(path)
  end

  @impl StorageConnector
  def directory_exists?(path, connector_state) do
    path = clean_path(path)

    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      virtual_directory?(config, path, connector_state) ||
        s3_prefix_exists?(config, path)
    end
  end

  @impl StorageConnector
  def make_directory(path, connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      path = clean_path(path)

      parent_dirs =
        path
        |> Path.dirname()
        |> Path.split()
        |> Enum.drop(-1)
        |> Enum.map(fn p -> clean_path(p) end)

      dirs = parent_dirs ++ [path]

      current_v_dirs = get_virtual_directories(config, connector_state)

      new_v_dirs = Enum.uniq(current_v_dirs ++ dirs)

      connector_state = Map.put(connector_state, :virtual_directories, new_v_dirs)
      {:ok, connector_state}
    end
  end

  @impl StorageConnector
  def delete_directory(path, connector_state) do
    path = Path.join(path, "") <> "/"

    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      if directory_exists?(path, connector_state) do
        delete_s3_prefix(config, path)
      end

      current_v_dirs = get_virtual_directories(config, connector_state)

      new_v_dirs = Enum.uniq((current_v_dirs -- [path]) ++ ["/"])

      connector_state = Map.put(connector_state, :virtual_directories, new_v_dirs)
      {:ok, connector_state}
    end
  end

  @impl StorageConnector
  def get_directory_contents(path, %{} = connector_state) do
    path = Path.join(path, "") <> "/"

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

      # TODO: Streaming evaluation
      stream =
        bucket
        |> ExAws.S3.download_file(prefix, :memory, chunk_size: 5 * 1024 * 1024)
        |> ExAws.stream!()
        |> Enum.into(<<>>)

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
          stream
          |> chunk_stream(opts)
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
      path = Path.join(path, "")

      config
      |> s3_get_prefix_contents(path, connector_state, :key)
      |> case do
        [content | _] -> {:ok, content}
        _ -> {:error, "Could not get content info"}
      end
    end
  end

  defp s3_get_prefix_contents(config, path, connector_state, type \\ :prefix)

  defp s3_get_prefix_contents(%{storage_bucket: nil} = _config, "/" = _path, _connector_state, _type) do
    with {:ok, %{body: %{buckets: buckets}}} <-
           ExAws.request(ExAws.S3.list_buckets()) do
      Enum.map(buckets, fn bucket -> to_content_info(bucket, nil) end)
    end
  end

  defp s3_get_prefix_contents(%{} = config, path, connector_state, type) do
    bucket = get_bucket(config, path)
    prefix = get_prefix(config, bucket, path)
    prefix = prefix || ""
    prefix = if type == :key, do: Path.join(prefix, ""), else: Path.join(prefix, "") <> "/"

    objects =
      if bucket do
        # yes I know I'm forcing evaluation
        # TODO: figure out how to append to a stream
        # Its probably a stream.resource() wrapper
        bucket
        |> ExAws.S3.list_objects(prefix: prefix, delimiter: "/", stream_prefixes: true)
        |> ExAws.stream!()
        |> Enum.map(fn thing ->
          to_content_info(thing, prefix)
        end)
      else
        []
      end

    current_v_dirs = get_virtual_directories(config, connector_state)

    objects_to_append =
      current_v_dirs
      |> Enum.filter(fn v_dir ->
        starts_with = String.starts_with?(v_dir, path)
        direct_child = Enum.count(Path.split(v_dir)) == Enum.count(Path.split(path)) + 1
        starts_with && direct_child
      end)
      |> Enum.map(fn v_dir ->
        to_content_info(%{prefix: Path.basename(v_dir)}, nil)
      end)

    objects ++ objects_to_append
  end

  defp to_content_info(%{prefix: prefix}, _parent_prefix) do
    %{
      file_name: Path.join(prefix, "") <> "/",
      modified_datetime: DateTime.from_unix!(0),
      size: 4096,
      access: :read_write,
      type: :directory
    }
  end

  defp to_content_info(%{key: filename, last_modified: last_mod_str}, parent_prefix) do
    {:ok, modified_datetime, _} = DateTime.from_iso8601(last_mod_str)

    %{
      file_name: String.replace(filename, parent_prefix, ""),
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
      bucket
      |> ExAws.S3.list_objects(prefix: prefix)
      |> ExAws.stream!()
      |> Stream.map(& &1.key)

    bucket
    |> ExAws.S3.delete_all_objects(stream)
    |> ExAws.request()
  end

  defp s3_prefix_exists?(%{storage_bucket: nil}, "/" = _path) do
    true
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
  defp get_bucket(%{storage_bucket: storage_bucket} = _config, _path) when not is_nil(storage_bucket), do: storage_bucket

  # / == list buckets
  defp get_bucket(%{storage_bucket: nil} = _config, "/" = _path), do: nil

  # /path == s3://path/
  defp get_bucket(%{storage_bucket: nil} = _config, path) do
    path
    |> Path.split()
    |> case do
      ["/", bucket | _] -> bucket
      _ -> nil
    end
  end

  # / == s3://storage_bucket/
  defp get_prefix(%{storage_bucket: storage_bucket} = _config, _bucket, "/" = _path) when not is_nil(storage_bucket) do
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
    prefix = String.replace(path, ~r/^\//, "")

    if "" == prefix, do: nil, else: prefix
  end

  defp bucket_exists?(nil), do: false

  defp bucket_exists?(bucket) do
    bucket
    |> ExAws.S3.head_bucket()
    |> ExAws.request()
    |> case do
      {:ok, %{status_code: 200}} -> true
      _ -> false
    end
  end

  defp prefix_exists?(bucket, nil = _prefix) when not is_nil(bucket), do: bucket_exists?(bucket)

  defp prefix_exists?(bucket, prefix) when not is_nil(bucket) do
    empty? =
      bucket
      |> ExAws.S3.list_objects(delimiter: "/", prefix: prefix)
      |> ExAws.stream!()
      |> Enum.take(1)
      |> Enum.empty?()

    !empty?
  end

  defp prefix_exists?(_bucket, _prefix), do: true

  defp get_virtual_directories(_config, %{virtual_directories: dirs}) do
    dirs
  end

  defp get_virtual_directories(%{storage_bucket: _bucket} = _config, connector_state) do
    Map.get(connector_state, :virtual_directories, ["/"])
  end
end
