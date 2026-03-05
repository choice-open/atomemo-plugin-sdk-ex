defmodule AtomemoPluginSdk.MixProject do
  use Mix.Project

  def project do
    [
      app: :atomemo_plugin_sdk,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
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
      {:req, "~> 0.5"}
    ]
  end
end
