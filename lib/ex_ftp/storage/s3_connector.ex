# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.S3Connector do
  @moduledoc """
  When **storage_connector** is `ExFTP.Storage.S3Connector`, this connector will use any S3-compatible storage provider.

  Underneath the hood, ex_ftp is using `ExAws.S3`, so you'll need that configured properly.

  <!-- tabs-open -->
  ### ⚙️ Configuration

  *Keys*

  * **storage_connector**  == `ExFTP.Storage.FileConnector`
  * **storage_config**  :: `t:ExFTP.Storage.S3ConnectorConfig.t/0`

  *Example*

  ```elixir
    %{
      # ... ,
      storage_connector: ExFTP.Storage.S3Connector,
      storage_config: %{
          # the `/` path of the FTP server will point to s3://{my-storage-bucket}/
          storage_bucket: "my-storage-bucket"
      }
  }
  ```

  #{ExFTP.Doc.related(["`ExFTP.StorageConnector`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """

  @behaviour ExFTP.StorageConnector

  import ExFTP.Storage.Common

  alias ExFTP.Storage.S3ConnectorConfig
  alias ExFTP.StorageConnector

  @doc """
  Returns the current working directory

  <!-- tabs-open -->

  ### 🏷️ Params
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  ### 💻 Examples

      iex> alias ExFTP.Storage.S3Connector
      iex> S3Connector.get_working_directory(%{current_working_directory: "/"})
      "/"


  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_working_directory/1`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec get_working_directory(connector_state :: ExFTP.StorageConnector.connector_state()) ::
          String.t()
  def get_working_directory(%{current_working_directory: cwd} = _connector_state), do: cwd

  @doc """
  Whether a given path is an existing directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.S3Connector
      iex> S3Connector.directory_exists?("/", %{current_working_directory: "/"})
      true
      iex> S3Connector.directory_exists?("/does-not-exist", %{current_working_directory: "/"})
      false

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.directory_exists?/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec directory_exists?(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) :: boolean
  def directory_exists?(path, connector_state) do
    path = clean_path(path)

    if path == "/" do
      true
    else
      with {:ok, config} <- validate_config(S3ConnectorConfig) do
        virtual_directory?(config, path, connector_state) ||
          s3_prefix_exists?(config, path)
      end
    end
  end

  @doc """
  Creates a directory, given a path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.S3Connector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir_to_make = "/new_dir/"
      iex> {:ok, connector_state} = S3Connector.make_directory(dir_to_make, connector_state)
      iex> S3Connector.directory_exists?(dir_to_make, connector_state)
      true

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.make_directory/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec make_directory(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) :: {:ok, ExFTP.StorageConnector.connector_state()} | {:error, term()}
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

  @doc """
  Deletes a given directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.S3Connector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir_to_make = "/new_dir"
      iex> {:ok, connector_state} = S3Connector.make_directory(dir_to_make, connector_state)
      iex> dir_to_rm = dir_to_make
      iex> {:ok, connector_state} = S3Connector.delete_directory(dir_to_rm, connector_state)
      iex> S3Connector.directory_exists?(dir_to_rm, connector_state)
      false

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.delete_directory/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec delete_directory(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) :: {:ok, ExFTP.StorageConnector.connector_state()} | {:error, term()}
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

  @doc """
  Deletes a given file

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.delete_file/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec delete_file(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) :: {:ok, ExFTP.StorageConnector.connector_state()} | {:error, term()}
  def delete_file(path, connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      bucket = get_bucket(config, path)
      key = get_prefix(config, bucket, path)

      bucket
      |> ExAws.S3.delete_object(key)
      |> ExAws.request!()

      {:ok, connector_state}
    end
  end

  @doc """
  Returns a list of `t:ExFTP.StorageConnector.content_info/0` representing each object in a given directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, [%{...}, ...]}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.S3Connector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir = "/"
      iex> {:ok, _content_infos} = S3Connector.get_directory_contents(dir, connector_state)

  #{ExFTP.Doc.related(["`t:ExFTP.StorageConnector.content_info/0`", "`c:ExFTP.StorageConnector.get_directory_contents/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec get_directory_contents(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) ::
          {:ok, [ExFTP.StorageConnector.content_info()]} | {:error, term()}
  def get_directory_contents(path, %{} = connector_state) do
    path = Path.join(path, "") <> "/"

    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      contents = s3_get_prefix_contents(config, path, connector_state)
      {:ok, contents}
    end
  end

  @doc """
  Returns a stream to read the raw bytes of an object specified by a given path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, data}", failure: "{:error, err}")}  

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_content/2`"])}

  #{ExFTP.Doc.resources("page-30")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec get_content(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) :: {:ok, any()} | {:error, term()}
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

  @doc """
  Create a function/1 that writes a **stream** to storage

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`
    * **opts** :: list of options

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec create_write_func(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state(),
          opts :: list()
        ) :: function()
  def create_write_func(path, connector_state, opts \\ []) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      bucket = get_bucket(config, path)
      prefix = get_prefix(config, bucket, path)

      fn stream ->
        try do
          stream
          |> chunk_stream(opts)
          |> ExAws.S3.upload(bucket, prefix)
          |> ExAws.request!()

          {:ok, connector_state}
        rescue
          _ -> {:error, "Failed to transfer"}
        end
      end
    end
  end

  @doc """
  Returns a `t:ExFTP.StorageConnector.content_info/0` representing a given path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, %{...}}", failure: "{:error, err}")}

  #{ExFTP.Doc.related(["`t:ExFTP.StorageConnector.content_info/0`", "`c:ExFTP.StorageConnector.get_content_info/2`", "`get_directory_contents/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec get_content_info(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state()
        ) ::
          {:ok, ExFTP.StorageConnector.content_info()} | {:error, term()}
  def get_content_info(path, connector_state) do
    with {:ok, config} <- validate_config(S3ConnectorConfig) do
      path = Path.join(path, "")

      contents = s3_get_prefix_contents(config, path, connector_state, :key)

      empty? = Enum.empty?(contents)

      if empty? do
        {:error, "Could not get content info"}
      else
        {:ok, contents |> Enum.take(1) |> hd()}
      end
    end
  end

  defp clean_path(path) do
    path =
      path
      |> String.replace("//", "/")
      |> Path.join("")

    path = "#{path}/"
    p = if String.starts_with?(path, "/"), do: path, else: "/#{path}"
    String.replace(p, "//", "/")
  end

  defp virtual_directory?(config, path, connector_state) do
    path = clean_path(path)

    config
    |> get_virtual_directories(connector_state)
    |> Enum.member?(path)
  end

  defp s3_get_prefix_contents(config, path, connector_state, type \\ :prefix)

  defp s3_get_prefix_contents(%{} = config, path, connector_state, type) do
    bucket = get_bucket(config, path)
    prefix = get_prefix(config, bucket, path)
    prefix = prefix || "/"
    prefix = if type == :key, do: Path.join(prefix, ""), else: clean_path(prefix)

    prefix =
      if prefix == "/",
        do: "",
        else: Path.join("", prefix) <> "/"

    prefix = if type == :key, do: Path.join(prefix, ""), else: prefix

    objects_stream =
      if bucket do
        bucket
        |> ExAws.S3.list_objects(prefix: prefix, delimiter: "/", stream_prefixes: true)
        |> ExAws.stream!()
        |> Stream.map(fn thing ->
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

    Stream.concat(objects_stream, objects_to_append)
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

  defp to_content_info(%{key: filename, last_modified: last_mod_str, size: size}, parent_prefix) do
    {:ok, modified_datetime, _} = DateTime.from_iso8601(last_mod_str)

    %{
      file_name: String.replace(filename, parent_prefix, ""),
      modified_datetime: modified_datetime,
      size: size,
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
