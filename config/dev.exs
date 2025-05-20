import Config

config :ex_aws,
  s3: [
    scheme: "http://",
    host: System.get_env("AWS_HOST"),
    port: 4566,
    access_key_id: "",
    secret_access_key: ""
  ]

config :ex_ftp,
  ftp_port: "FTP_PORT" |> System.get_env("4040") |> String.to_integer(),
  min_passive_port: "MIN_PASSIVE_PORT" |> System.get_env("40002") |> String.to_integer(),
  max_passive_port: "MAX_PASSIVE_PORT" |> System.get_env("40007") |> String.to_integer(),
  authenticator: ExFTP.Auth.PassthroughAuth,
  storage_config: %{storage_bucket: "ex-ftp-test"},
  storage_connector: ExFTP.Storage.S3Connector
