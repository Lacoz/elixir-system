import Config

database_url =
  System.get_env("DATABASE_URL") || "postgresql://app:app@localhost:5432/app_test"

config :es_kernel, EsKernel.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox
