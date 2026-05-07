import Config

database_url =
  System.get_env("DATABASE_URL") || "postgresql://app:app@localhost:5432/app_test"

config :es_kernel,
  caps_path: "test/fixtures/minimal_caps.toml",
  caps_lock_path: "test/fixtures/caps.lock.missing",
  enable_caps_watcher: false

config :es_kernel, EsKernel.Repo,
  url: database_url,
  pool: Ecto.Adapters.SQL.Sandbox
