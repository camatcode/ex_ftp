defmodule ExFTP.MixProject do
  use Mix.Project

  @source_url "https://github.com/camatcode/ex_ftp"
  @version "0.9.0"

  def project do
    [
      app: :ex_ftp,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

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
        ExFTP.Auth.PassthroughAuth,
        ExFTP.Auth.NoAuth,
        ExFTP.Auth.WebhookAuth,
        ExFTP.Auth.BearerAuth,
        ExFTP.Auth.BasicAuth,
        ExFTP.Auth.DigestAuth
      ],
      "Authenticator Config": [
        ExFTP.Auth.Common,
        ExFTP.Auth.WebhookAuthConfig,
        ExFTP.Auth.BearerAuthConfig,
        ExFTP.Auth.BasicAuthConfig,
        ExFTP.Auth.DigestAuthConfig
      ],
      "Storage Connector": [
        ExFTP.StorageConnector,
        ExFTP.Storage.FileConnector,
        ExFTP.Storage.S3Connector
      ],
      "Storage Connector Config": [
        ExFTP.Storage.S3ConnectorConfig
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
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:ex_license, "~> 0.1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:faker, "~> 0.18.0", only: :test},
      {:req, "~> 0.5.10"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:poison, "~> 5.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.7"},
      {:configparser_ex, "~> 4.0"},
      {:cachex, "~> 4.0"},
      {:proper_case, "~> 1.3"}
    ]
  end
end
