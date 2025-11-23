# SPDX-License-Identifier: Apache-2.0
defmodule ExFTP.StorageConnector do
  @moduledoc """
  A behaviour defining a Storage Connector.

  Storage Connectors are used by the FTP interface to interact with a particular type of storage.

  <!-- tabs-open -->

  ### Custom Connectors

  To create a custom storage connector, implement all callbacks in this behaviour:

      # SPDX-License-Identifier: Apache-2.0
      defmodule MyStorageConnector do
        @moduledoc false

        @behaviour ExFTP.StorageConnector

        alias ExFTP.StorageConnector

        @impl StorageConnector
        @spec get_working_directory(connector_state :: StorageConnector.connector_state()) ::
                String.t()
        def get_working_directory(%{current_working_directory: cwd} = _connector_state) do
          # returns the current directory, for most cases this is just a pass through
          # however, you might want to modify what the current directory is
          # based on some state
        end

        @impl StorageConnector
        @spec directory_exists?(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: boolean
        def directory_exists?(path, _connector_state) do
          # Given a path, does this directory exist in storage?
        end

        @impl StorageConnector
        @spec make_directory(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
        def make_directory(path, connector_state) do
          # Given a path, make a directory
          # For S3-like connectors, a "directory" doesn't really exist
          #  so those connectors typically keep track of virtual directories
          #  that we're created by user during the session
          #  if they're unused, they aren't persisted.
        end

        @impl StorageConnector
        @spec delete_directory(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
        def delete_directory(path, connector_state) do
          # Give a path, delete the directory
        end

        @impl StorageConnector
        @spec delete_file(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: {:ok, StorageConnector.connector_state()} | {:error, term()}
        def delete_file(path, connector_state) do
          # Give a path, delete the file
        end

        @impl StorageConnector
        @spec get_directory_contents(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) ::
                {:ok, [StorageConnector.content_info()]} | {:error, term()}
        def get_directory_contents(path, connector_state) do
          # returns a list of content_infos
          # the model for them was inspired by File.lstat()
          # Have a look at StorageConnector.content_info type
        end

        @impl StorageConnector
        @spec get_content_info(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) ::
                {:ok, StorageConnector.content_info()} | {:error, term()}
        def get_content_info(path, _connector_state) do
          # given a path, return information on the file/directory there
          # Have a look at StorageConnector.content_info type
        end

        @impl StorageConnector
        @spec get_content(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: {:ok, any()} | {:error, term()}
        def get_content(path, _connector_state) do
          # Return a {:ok, stream} of path
        end

        @impl StorageConnector
        @spec create_write_func(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state(),
                opts :: list()
              ) :: function()
        def create_write_func(path, connector_state, opts \\\\ []) do
          # Return a function that will write `stream` to your storage at path
          # e.g
          # fn stream ->
          #  fs = File.stream!(path)
          #
          #  try do
          #    _ =
          #      stream
          #      |> chunk_stream(opts)
          #      |> Enum.into(fs)
          #
          #    {:ok, connector_state}
          #  rescue
          #    _ ->
          #      {:error, "Failed to transfer"}
          #  end
          #end
        end
      end


  ### User Scopes

  All `connector_state` maps contain the `authenticator_state` map, which contains `username` and any metadata added by the Authenticator

        @impl StorageConnector
        @spec get_content(
                path :: StorageConnector.path(),
                connector_state :: StorageConnector.connector_state()
              ) :: {:ok, any()} | {:error, term()}
        def get_content(path, connector_state) do
          # Access the authenticated user's information
          # username = connector_state.authenticator_state.username
          # Scope the path to the user's directory
          # scoped_path = Path.join(["/users", username, path])
        end
        # ... implement other callbacks similarly
      end

  #{ExFTP.Doc.related(["`ExFTP.Storage.FileConnector`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """

  @typedoc """
  A Port representing a socket to communicate with an FTP client.

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Sockets are everywhere {: .tip}
  >
  > This socket represents the TCP connection between the FTP Server and the client (often through port 21)
  >
  > While related, this socket is not a PASV socket, which is a negotiated, temporary socket
  > for sending or receiving data.

  #{ExFTP.Doc.resources()}
  <!-- tabs-close -->
  """
  @type socket :: port()

  @typedoc """
  State held onto by the server and modified by the `StorageConnector`.

  It may be used by the storage connector to keep stateful values.

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Special Keys {: .tip}
  >
  >   * `current_working_directory:` `t:String.t/0` always present. Represents the "directory" we're operating from.
  >   * `authenticator_state:` `ExFTP.Authenticator.authenticator_state()` always present when callbacks are invoked. Contains the authenticated user's information (including username) and any custom data stored by the authenticator. Storage connector callbacks are only invoked after successful authentication.

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->

  """
  @type connector_state :: %{}

  @doc """
  Returns the current working directory

  <!-- tabs-open -->

  ### 🏷️ Params
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "(The working directory)")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> FileConnector.get_working_directory(%{current_working_directory: "/"})
      "/"

  ### ⚠️ Reminders
  > #### Doesn't the connector_state already have it? {: .tip}
  >
  > Most Storage Connectors will just return what's already in the **connector_state**.
  > However, this method is implemented just in case a Connector has a different way of
  > determining the current working directory.

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback get_working_directory(connector_state) :: String.t()

  @typedoc """
  A string representing a file path (e.g `"/path/to/file.txt"` or `"/path/to/dir/"`)

  <!-- tabs-open -->

  ### ⚠️ Reminders
  > #### Relative paths {: .tip}
  >
  > The Server will ensure all paths sent to the connector are *absolute* paths,
  > so you don't need to worry about handling relative paths, or `..` notations

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @type path :: String.t()
  @doc """
  Whether a given path is an existing directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "`true` or `false`")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> FileConnector.directory_exists?("/tmp", %{current_working_directory: "/"})
      true
      iex> FileConnector.directory_exists?("/does-not-exist", %{current_working_directory: "/"})
      false

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback directory_exists?(path, connector_state) :: boolean

  @doc """
  Creates a directory, given a path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir_to_make = File.cwd!() |> Path.join("new_dir")
      iex> {:ok, connector_state} = FileConnector.make_directory(dir_to_make, connector_state)
      iex> FileConnector.directory_exists?(dir_to_make, connector_state)
      true
      iex> {:ok, _connector_state} = FileConnector.delete_directory(dir_to_make, connector_state)
      iex> FileConnector.directory_exists?(dir_to_rm, connector_state)
      false

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback make_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @doc """
  Deletes a given directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

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

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback delete_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @doc """
  Deletes a given file

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, connector_state}", failure: "{:error, err}")}

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback delete_file(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @typedoc """
  Information about a given file, directory, or symlink

  <!-- tabs-open -->

  ### 🏷️ Keys
    * **filename** :: `t:String.t/0` e.g "my_file.txt", "my_dir/" or "my_sym_link -> target/"
    * **modified_datetime** :: `t:DateTime.t/0`
    * **size** :: `integer` e.g  1000
    * **access** :: `:read | :write | :read_write | :none`
    * **type** :: `:directory | :symlink | :file`

  #{ExFTP.Doc.related(["`c:get_content_info/2`", "`c:get_directory_contents/2`"])}

  #{ExFTP.Doc.resources()}

  <!-- tabs-close -->
  """
  @type content_info :: %{
          file_name: String.t(),
          modified_datetime: DateTime.t(),
          size: integer,
          access: :read | :write | :read_write | :none,
          type: :directory | :symlink | :file
        }

  @doc """
  Returns a list of `t:content_info/0` representing each object in a given directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, [%{...}, ...]}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> dir = File.cwd!()
      iex> {:ok, _content_infos} = FileConnector.get_directory_contents(dir, connector_state)

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback get_directory_contents(path, connector_state) ::
              {:ok, [content_info]} | {:error, term()}

  @doc """
  Returns `t:content_info/0` representing a single object in a given directory

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, %{...}}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> file_to_get_info = File.cwd!() |> File.ls!() |> hd()
      iex> path = Path.join(File.cwd!(), file_to_get_info)
      iex> {:ok, content_info} = FileConnector.get_content_info(path, connector_state)

  #{ExFTP.Doc.resources("page-32")}

  <!-- tabs-close -->
  """
  @callback get_content_info(path, connector_state) :: {:ok, content_info} | {:error, term()}

  @doc """
  Returns a stream to read the raw bytes of an object specified by a given path

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`

  #{ExFTP.Doc.returns(success: "{:ok, data}", failure: "{:error, err}")}

  ### 💻 Examples

      iex> alias ExFTP.Storage.FileConnector
      iex> connector_state = %{current_working_directory: "/"}
      iex> file_to_get_content = File.cwd!() |> File.ls!() |> Enum.filter(&String.contains?(&1,".")) |> hd()
      iex> path = Path.join(File.cwd!(), file_to_get_content)
      iex> {:ok, _data} = FileConnector.get_content(path, connector_state)

  #{ExFTP.Doc.resources("page-30")}

  <!-- tabs-close -->
  """
  @callback get_content(path, connector_state) :: {:ok, any()} | {:error, term()}

  @doc """
  Create a function/1 that writes a **stream** to storage

  <!-- tabs-open -->
  ### 🏷️ Params
    * **path** :: `t:path/0`
    * **connector_state** :: `t:connector_state/0`
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
  @callback create_write_func(path, connector_state, opts :: list()) :: function()
end
