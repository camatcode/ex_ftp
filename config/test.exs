import Config

config :ex_aws,
  region: {:system, "AWS_REGION"}

config :ex_ftp,
  ftp_port: 4041,
  min_passive_port: System.get_env("MIN_PASSIVE_PORT", "40002") |> String.to_integer(),
  max_passive_port: System.get_env("MAX_PASSIVE_PORT", "40007") |> String.to_integer(),
  authenticator: ExFTP.Auth.PassthroughAuth,
  authenticator_config: %{
    authenticated_url: nil,
    authenticated_method: :get,
    authenticated_ttl_ms: 24 * 60 * 60 * 60 * 1000,
    login_url: nil,
    login_method: :get
  },
  storage_connector: ExFTP.Storage.FileConnector
