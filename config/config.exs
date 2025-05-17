# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ex_ftp,
  ftp_port: "FTP_PORT" |> System.get_env("4040") |> String.to_integer(),
  min_passive_port: "MIN_PASSIVE_PORT" |> System.get_env("40002") |> String.to_integer(),
  max_passive_port: "MAX_PASSIVE_PORT" |> System.get_env("40007") |> String.to_integer(),
  authenticator: ExFTP.Auth.PassthroughAuth,
  authenticator_config: %{
    authenticated_url: nil,
    authenticated_method: :get,
    login_url: nil,
    login_method: :get
  },
  storage_connector: ExFTP.Storage.FileConnector

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
