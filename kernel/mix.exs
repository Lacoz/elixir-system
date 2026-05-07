defmodule EsKernel.MixProject do
  use Mix.Project

  def project do
    [
      app: :es_kernel,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:telemetry, "~> 1.0"},
      {:plug, "~> 1.17"},
      {:file_system, "~> 1.1"},
      {:phoenix_pubsub, "~> 2.2"},
      {:toml, "~> 0.7"}
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {EsKernel.Application, []}]
  end
end
