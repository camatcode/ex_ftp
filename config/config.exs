# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ex_ftp,
  ftp_port: System.get_env("FTP_PORT", "4040") |> String.to_integer(),
  min_passive_port: System.get_env("MIN_PASSIVE_PORT", "40002") |> String.to_integer(),
  max_passive_port: System.get_env("MAX_PASSIVE_PORT", "40007") |> String.to_integer()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
