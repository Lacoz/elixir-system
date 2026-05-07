defmodule ElixirSystem.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_system,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [{:es_kernel, path: "kernel"}]
  end

  defp aliases do
    [test: ["compile", "test"]]
  end
end
