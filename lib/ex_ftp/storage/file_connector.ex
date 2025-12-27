# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.FileConnector do
  @moduledoc """
  When **storage_connector** is `ExFTP.Storage.FileConnector`, this connector will use the file system of where
  it is running.

  This is the out-of-the-box behavior you'd expect from any FTP server.

  > #### 🔒 Security {: .warning}
  >
  > Currently, there is no file access management per user.
  >
  > Authenticated users perform file system actions as if they were the FTP user

  <!-- tabs-open -->

  ### ⚙️ Configuration

  *Keys*

  * **storage_connector**  == `ExFTP.Storage.FileConnector`
  * **storage_config**  == `%{}`

  *Example*

  ```elixir
    %{
      # ... ,
      storage_connector: ExFTP.Storage.FileConnector,
      storage_config: %{}
    }
  ```

  #{ExFTP.Doc.related(["`ExFTP.StorageConnector`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @behaviour ExFTP.StorageConnector

  import ExFTP.Storage.Common

  alias ExFTP.StorageConnector

  @doc """
  Returns the current working directory

  <!-- tabs-open -->

  ### 🏷️ Params
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> FileConnector.get_working_directory(%{current_working_directory: "/"})
      "/"


  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_working_directory/1`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec get_working_directory(connector_state :: ExFTP.StorageConnector.connector_state()) :: String.t()
  def get_working_directory(connector_state), do: connector_state[:current_working_directory]

  @doc """
  Whether a given path is an existing directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> FileConnector.directory_exists?("/tmp", %{current_working_directory: "/"})
      true
      iex> FileConnector.directory_exists?("/does-not-exist", %{current_working_directory: "/"})
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
  def directory_exists?(path, _connector_state), do: File.exists?(path) && File.dir?(path)

  @doc """
  Creates a directory, given a path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir_to_make = File.cwd!() |> Path.join("new_dir")
      iex> {:ok, connector_state} = FileConnector.make_directory(dir_to_make, connector_state)
      iex> FileConnector.directory_exists?(dir_to_make, connector_state)
      true
      iex> dir_to_rm = dir_to_make
      iex> {:ok, connector_state} = FileConnector.delete_directory(dir_to_rm, connector_state)
      iex> FileConnector.directory_exists?(dir_to_rm, connector_state)
      false

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
    path
    |> File.mkdir_p()
    |> case do
      :ok -> {:ok, connector_state}
      err -> err
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

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir_to_make = File.cwd!() |> Path.join("new_dir")
      iex> {:ok, connector_state} = FileConnector.make_directory(dir_to_make, connector_state)
      iex> dir_to_rm = dir_to_make
      iex> {:ok, connector_state} = FileConnector.delete_directory(dir_to_rm, connector_state)
      iex> FileConnector.directory_exists?(dir_to_rm, connector_state)
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
    path
    |> rmrf_dir()
    |> case do
      {:ok, _} -> {:ok, connector_state}
      err -> err
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
    if File.regular?(path) do
      File.rm(path)
      {:ok, connector_state}
    else
      {:error, :not_a_file}
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

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir = File.cwd!()
      iex> {:ok, _content_infos} = FileConnector.get_directory_contents(dir, connector_state)

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
  def get_directory_contents(path, connector_state) do
    with {:ok, files} <- File.ls(path) do
      contents =
        Enum.map(files, fn file_name ->
          {:ok, content_info} = get_content_info(Path.join(path, file_name), connector_state)
          content_info
        end)

      {:ok, contents}
    end
  end

  @doc """
  Returns a `t:ExFTP.StorageConnector.content_info/0` representing a given path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, %{...}}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> file_to_get_info = File.cwd!() |> File.ls!() |> hd()
      iex> path = Path.join(File.cwd!(), file_to_get_info)
      iex> {:ok, _content_info} = FileConnector.get_content_info(path, connector_state)

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
  def get_content_info(path, _connector_state) do
    with {:ok, l_stat} <- File.lstat(path) do
      %{
        size: size,
        mtime: {{year, month, day}, {hour, minute, second}},
        access: access,
        type: type
      } = l_stat

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
    end
  end

  @doc """
  Returns a stream to read the raw bytes of an object specified by a given path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, data}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> file_to_get_content = File.cwd!() |> File.ls!() |> Enum.filter(&String.contains?(&1,".")) |> hd()
      iex> path = Path.join(File.cwd!(), file_to_get_content)
      iex> {:ok, _data} = FileConnector.get_content(path, connector_state)

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
    if File.exists?(path) && File.regular?(path) do
      {:ok, File.stream!(path)}
    else
      {:error, "Cannot read"}
    end
  end

  @doc """
  Create a function/1 that writes a **stream** to storage

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:ExFTP.StorageConnector.path/0`
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`
    * **opts** :: list of options

  ### 💻 Examples

  ```elixir
      @impl StorageConnector
      def create_write_func(path, connector_state, opts \\ []) do
        fn stream ->
          fs = File.stream!(path)

          try do
            _ =
              stream
              |> chunk_stream(opts)
              |> Enum.into(fs)

            {:ok, connector_state}
          rescue
            _ ->
              {:error, "Failed to transfer"}
          end
        end
      end
  ```

  <!-- tabs-close -->
  """
  @impl StorageConnector
  @spec create_write_func(
          path :: ExFTP.StorageConnector.path(),
          connector_state :: ExFTP.StorageConnector.connector_state(),
          opts :: list()
        ) :: function()
  def create_write_func(path, connector_state, opts \\ []) do
    fn stream ->
      fs = File.stream!(path)

      _ =
        stream
        |> chunk_stream(opts)
        |> Enum.into(fs)

      {:ok, connector_state}
    end
  end

  defp rmrf_dir("/"), do: {:error, "Not something to delete"}

  defp rmrf_dir(dir) do
    if File.exists?(dir) && File.dir?(dir) do
      File.rm_rf(dir)
    else
      {:error, "Not something to delete"}
    end
  end
end
