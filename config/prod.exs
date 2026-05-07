import Config

pool_size =
  case System.get_env("POOL_SIZE") do
    nil -> 10
    s -> String.to_integer(s)
  end

config :es_kernel, EsKernel.Repo, pool_size: pool_size
