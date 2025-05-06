import Config

config :studio_ftp,
  min_passive_port: System.get_env("MIN_PASSIVE_PORT", "40002") |> String.to_integer(),
  max_passive_port: System.get_env("MAX_PASSIVE_PORT", "40007") |> String.to_integer()
