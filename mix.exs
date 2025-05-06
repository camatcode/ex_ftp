defmodule Ftp2Cloud.MixProject do
  use Mix.Project

  @source_url "https://github.com/camatcode/ftp_2_cloud"
  @version "0.9.0"

  def project do
    [
      app: :ftp_2_cloud,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      package: package(),
      description: """
      Adds an FTP interface to your cloud service provider
      """,

      # Docs
      name: "FTP2Cloud",
      docs: [
        main: "FTP2Cloud",
        api_reference: false,
        logo: "assets/ftp_2_cloud-logo.png",
        source_ref: "v#{@version}",
        source_url: @source_url,
        extra_section: "GUIDES",
        extras: extras(),
        formatters: ["html"],
        extras: extras(),
        groups_for_modules: groups_for_modules(),
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  defp groups_for_modules do
    []
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:ex_license, "~> 0.1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_machina, "~> 2.8.0", only: :test},
      {:faker, "~> 0.18.0", only: :test},
      {:req, "~> 0.5.10"},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:poison, "~> 5.0"},
      {:hackney, "~> 1.9"},
      {:sweet_xml, "~> 0.7"},
      {:configparser_ex, "~> 4.0"}
    ]
  end
end
