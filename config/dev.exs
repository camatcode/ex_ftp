import Config

config :ex_aws,
  s3: [
    scheme: "http://",
    host: System.get_env("AWS_HOST"),
    port: 4566,
    access_key_id: "",
    secret_access_key: ""
  ]
