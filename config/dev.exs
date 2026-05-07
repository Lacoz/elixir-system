import Config

database_url =
  System.get_env("DATABASE_URL") || "postgresql://app:app@localhost:5432/app_dev"

config :es_kernel, EsKernel.Repo,
  url: database_url,
  pool_size: 10,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true
