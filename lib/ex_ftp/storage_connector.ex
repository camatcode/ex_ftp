defmodule ExFTP.StorageConnector do
  @moduledoc """
  A behaviour defining a Storage Connector.

  Storage Connectors are used by the FTP interface to interact with a particular type of storage.

  See `ExFTP.Connector.FileConnector` for a simple example.
  """

  @type socket :: %{}
  @type connector_state :: %{}

  @callback get_working_directory(connector_state) :: String.t()

  @type path :: String.t()
  @callback directory_exists?(path, connector_state) :: boolean

  @callback make_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @callback delete_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @type content_info :: %{
          file_name: String.t(),
          modified_datetime: DateTime.t(),
          size: integer,
          access: :read | :write | :read_write | :none,
          type: :directory | :symlink | :file
        }
  @callback get_directory_contents(path, connector_state) ::
              {:ok, [content_info]} | {:error, term()}

  @callback get_content_info(path, connector_state) :: {:ok, content_info} | {:error, term()}

  @callback get_content(path, connector_state) :: {:ok, any()} | {:error, term()}

  @type stream :: any()

  @callback open_write_stream(path, connector_state) :: {:ok, stream} | {:error, term()}

  @callback close_write_stream(stream, connector_state) :: {:ok, any()} | {:error, term()}
end
