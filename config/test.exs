import Config

config :ex_aws,
  s3: [
    scheme: System.get_env("AWS_SCHEME", "http://"),
    host: System.get_env("AWS_HOST", "localhost"),
    port: "AWS_PORT" |> System.get_env("4566") |> String.to_integer(),
    access_key_id: "",
    secret_access_key: ""
  ]

config :ex_ftp,
  ftp_port: "FTP_PORT" |> System.get_env("4041") |> String.to_integer(),
  ftp_addr: System.get_env("FTP_ADDR", "127.0.0.1"),
  min_passive_port: "MIN_PASSIVE_PORT" |> System.get_env("40002") |> String.to_integer(),
  max_passive_port: "MAX_PASSIVE_PORT" |> System.get_env("40007") |> String.to_integer(),
  authenticator: ExFTP.Auth.PassthroughAuth,
  authenticator_config: %{
    authenticated_url: nil,
    authenticated_method: :get,
    authenticated_ttl_ms: 24 * 60 * 60 * 60 * 1000,
    login_url: nil,
    login_method: :get
  },
  storage_connector: ExFTP.Storage.FileConnector
