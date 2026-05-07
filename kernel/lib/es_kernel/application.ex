defmodule EsKernel.Application do
  @moduledoc false
  use Application

  @impl Application
  def start(_type, _args) do
    pubsub_conf = Application.fetch_env!(:es_kernel, :capability_pubsub_options)

    children =
      [
        EsKernel.Repo,
        pubsub_child(pubsub_conf),
        {CapabilitySupervisor, []},
        {GrantRegistry.Server, []}
      ] ++ watcher_children()

    Supervisor.start_link(children, strategy: :one_for_one, name: EsKernel.Supervisor)
  end

  defp watcher_children do
    if Application.get_env(:es_kernel, :enable_caps_watcher, false) do
      [{CapabilityWatcher, []}]
    else
      []
    end
  end

  defp pubsub_child(options) when is_list(options) do
    {Phoenix.PubSub, options}
  end
end
