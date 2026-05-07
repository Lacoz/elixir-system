defmodule EsKernel.Repo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :es_kernel,
    adapter: Ecto.Adapters.Postgres,
    migration_timestamps: [type: :utc_datetime_usec]

  @impl true
  def init(_type, opts) do
    url = Keyword.get(opts, :url) || System.get_env("DATABASE_URL")
    {:ok, Keyword.put(opts, :url, url)}
  end
end
