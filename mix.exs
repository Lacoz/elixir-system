defmodule ElixirSystem.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_system,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_ignore_filters: [~r/^test\/support\//],
      test_coverage: [summary: [threshold: 0]]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:es_kernel, path: "kernel", runtime: Mix.env() != :test}]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create -r EsKernel.Repo", "ecto.migrate -r EsKernel.Repo"],
      test: ["compile", "test"]
    ]
  end
end
