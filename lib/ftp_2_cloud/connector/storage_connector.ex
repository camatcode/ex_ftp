defmodule FTP2Cloud.StorageConnector do
  @moduledoc false
  @type socket :: %{}
  @type connector_state :: %{}

  @callback get_working_directory(connector_state) :: String.t()

  @type path :: String.t()
  @callback directory_exists?(path, connector_state) :: boolean

  @callback make_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}

  @callback rm_directory(path, connector_state) :: {:ok, connector_state} | {:error, term()}
end
