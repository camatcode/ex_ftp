defmodule ExFTP.MixProject do
  use Mix.Project

  alias ExFTP.Auth.BasicAuth
  alias ExFTP.Auth.BasicAuthConfig
  alias ExFTP.Auth.BearerAuth
  alias ExFTP.Auth.BearerAuthConfig
  alias ExFTP.Auth.Common
  alias ExFTP.Auth.DigestAuth
  alias ExFTP.Auth.DigestAuthConfig
  alias ExFTP.Auth.NoAuth
  alias ExFTP.Auth.PassthroughAuth
  alias ExFTP.Auth.WebhookAuth
  alias ExFTP.Auth.WebhookAuthConfig
  alias ExFTP.Storage.FileConnector
  alias ExFTP.Storage.S3Connector
  alias ExFTP.Storage.S3ConnectorConfig

  @source_url "https://github.com/camatcode/ex_ftp"
  @version "1.0.4"

  def project do
    [
      app: :ex_ftp,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ],
      # Hex
      package: package(),
      description: """
      An extendable, lightweight FTP server with cloud integrations already built in
      """,

      # Docs
      name: "ExFTP",
      docs: [
        main: "ExFTP",
        api_reference: false,
        logo: "assets/ex_ftp-logo.png",
        source_ref: "v#{@version}",
        source_url: @source_url,
        extra_section: "GUIDES",
        formatters: ["html"],
        extras: extras(),
        groups_for_modules: groups_for_modules(),
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  defp groups_for_modules do
    [
      Authenticator: [
        ExFTP.Authenticator,
        PassthroughAuth,
        NoAuth,
        WebhookAuth,
        BearerAuth,
        BasicAuth,
        DigestAuth
      ],
      "Authenticator Config": [
        Common,
        WebhookAuthConfig,
        BearerAuthConfig,
        BasicAuthConfig,
        DigestAuthConfig
      ],
      "Storage Connector": [
        ExFTP.StorageConnector,
        FileConnector,
        S3Connector
      ],
      "Storage Connector Config": [
        S3ConnectorConfig
      ],
      Server: [ExFTP.Worker, ExFTP.Storage.Common, ExFTP.Common]
    ]
  end

  def package do
    [
      maintainers: ["Cam Cook"],
      licenses: ["Apache-2.0"],
      files: ~w(lib .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      links: %{
        Website: @source_url,
        Changelog: "#{@source_url}/blob/master/CHANGELOG.md",
        GitHub: @source_url
      }
    ]
  end

  def extras do
    [
      "README.md"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExFTP.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:ex_license, "~> 0.1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:quokka, "~> 2.9", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:test]},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:faker, "~> 0.18.0", only: :test},
      {:req, "~> 0.5"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:poison, "~> 6.0"},
      {:hackney, "~> 1.25"},
      {:sweet_xml, "~> 0.7"},
      {:configparser_ex, "~> 4.0"},
      {:cachex, "~> 4.1"},
      {:proper_case, "~> 1.3"}
    ]
  end
end
