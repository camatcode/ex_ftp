defmodule ExFTP.StorageConnector do
  @moduledoc """
  A behaviour defining a Storage Connector.

  Storage Connectors are used by the FTP interface to interact with a particular type of storage.

  See `ExFTP.Connector.FileConnector` for a simple example.
  """

  @typedoc """
  A map representing a socket to communicate with an FTP client
  """
  @type socket :: %{}

  @typedoc """
  State held onto by the server and modified by the `StorageConnector`.

  It will always contain `:current_working_directory` - but may be used by the connector to keep stateful values
  """
  @type connector_state :: %{}

  @doc """
  Returns the current working directory
  """
  @callback get_working_directory(connector_state) :: String.t()

  @typedoc """
  A string representing a file path (e.g `"/path/to/file.txt"` or `"/path/to/dir/"`)
  """
  @type path :: String.t()
  @doc """
  Whether a given path is an existing directory
  """
  @callback directory_exists?(path, connector_state) :: boolean

  @doc """
  Creates a directory, given a path
  """
  @callback make_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @doc """
  Deletes a given directory
  """
  @callback delete_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @typedoc """
  Information about a given file, directory, or symlink
  """
  @type content_info :: %{
          file_name: String.t(),
          modified_datetime: DateTime.t(),
          size: integer,
          access: :read | :write | :read_write | :none,
          type: :directory | :symlink | :file
        }

  @doc """
  Returns a list of `content_info` representing each object in a given directory
  """
  @callback get_directory_contents(path, connector_state) ::
              {:ok, [content_info]} | {:error, term()}

  @doc """
  Returns `content_info/0` representing a single object in a given directory
  """
  @callback get_content_info(path, connector_state) :: {:ok, content_info} | {:error, term()}

  @doc """
  Returns a stream to read the raw bytes of an object specified by a given path
  """
  @callback get_content(path, connector_state) :: {:ok, any()} | {:error, term()}

  @typedoc """
  A stream of bytes representing the raw bytes of an object
  """
  @type stream :: any()

  @doc """
  Returns a writable stream that can be sent bytes that will be written to a given path
  """
  @callback open_write_stream(path, connector_state) :: {:ok, stream} | {:error, term()}

  @doc """
  Notification that the stream is finished writing and may be released and closed.
  """
  @callback close_write_stream(stream, connector_state) :: {:ok, any()} | {:error, term()}
end
