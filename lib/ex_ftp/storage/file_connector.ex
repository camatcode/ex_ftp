# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.Storage.FileConnector do
  @moduledoc """
  An implementation of `ExFTP.StorageConnector` which serves content from local file storage.

  <!-- tabs-open -->

  #{ExFTP.Doc.related(["`ExFTP.StorageConnector`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @behaviour ExFTP.StorageConnector

  import ExFTP.Storage.Common
  import ExFTP.Common

  alias ExFTP.StorageConnector

  @doc """
  Returns the current working directory

  <!-- tabs-open -->

  ### 🏷️ Params
    * **connector_state** :: `t:ExFTP.StorageConnector.connector_state/0`

  #{ExFTP.Doc.returns(success: "(The working directory)")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> FileConnector.get_working_directory(%{current_working_directory: "/"})
      "/"


  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.get_working_directory/1`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @impl StorageConnector
  def get_working_directory(%{current_working_directory: cwd} = _connector_state), do: cwd

  @impl StorageConnector
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
  def directory_exists?(path, _connector_state) do
    File.exists?(path) && File.dir?(path)
  end

  @impl StorageConnector
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

  #{ExFTP.Doc.related(["`c:ExFTP.StorageConnector.make_directory/2`"])}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
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
  def get_content(path, _connector_state) do
    File.read(path)
  end

  @file_action_aborted 552
  @closing_connection_success 226

  @impl StorageConnector
  def get_write_func(path, socket, _connector_state, _opts \\ []) do
    fn stream, opts ->
      fs = File.stream!(path)

      try do
        chunk_stream(stream, opts)
        |> Enum.into(fs)

        send_resp(@closing_connection_success, "Transfer Complete.", socket)
      rescue
        _ -> send_resp(@file_action_aborted, "Failed to transfer.", socket)
      after
        nil
      end
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
