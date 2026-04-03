defmodule AtomemoPluginSdk.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :atomemo_plugin_sdk,
      version: @version,
      description: "Elixir SDK for Atomemo plugins.",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AtomemoPluginSdk.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.10"},
      {:polymorphic_embed, "~> 5.0"},
      {:slipstream, "~> 1.2"},
      {:req, "~> 0.5"},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: [],
      links: %{
        "GitHub" => "https://github.com/choice-open/atomemo-plugin-sdk-ex"
      },
      homepage_url: "https://atomemo.ai"
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  def cli do
    [
      preferred_envs: [check: :test]
    ]
  end

  defp aliases do
    [
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end
end
