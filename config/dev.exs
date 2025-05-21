import Config

alias ExFTP.Auth.PassthroughAuth
alias ExFTP.Storage.S3Connector

config :ex_aws,
  s3: [
    scheme: System.get_env("AWS_SCHEME", "http://"),
    host: System.get_env("AWS_HOST", "localhost"),
    port: "AWS_PORT" |> System.get_env("4566") |> String.to_integer(),
    access_key_id: "",
    secret_access_key: ""
  ]
