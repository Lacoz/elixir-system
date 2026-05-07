import Config

import_config "#{config_env()}.exs"

config :logger, :console, format: "$time $metadata[$level] $message\n"

if config_env() != :test do
  config :es_kernel,
    caps_path: System.get_env("CAPS_MANIFEST_PATH", "caps.toml"),
    caps_lock_path: System.get_env("CAPS_LOCK_PATH", "caps.lock")
end

config :es_kernel,
  capability_pubsub_options: [name: EsKernel.PubSub]
