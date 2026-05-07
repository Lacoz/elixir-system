defmodule CapabilityBus do
  @moduledoc false

  def emit(cap, event, payload, partition_id)
      when is_atom(cap) and is_atom(event) and is_map(payload) and is_binary(partition_id) do
    topic = topic(cap, event)
    meta = {:cap_event, cap, event, partition_id, payload}

    :telemetry.execute(
      [:es_kernel, :capability_bus, :emit],
      %{count: 1},
      %{cap: cap, event: event, partition_id: partition_id}
    )

    Phoenix.PubSub.broadcast(pubsub(), topic, meta)
    :ok
  end

  def subscribe(cap, event) when is_atom(cap) and is_atom(event) do
    Phoenix.PubSub.subscribe(pubsub(), topic(cap, event))
    :ok
  end

  defp pubsub do
    :es_kernel
    |> Application.fetch_env!(:capability_pubsub_options)
    |> Keyword.fetch!(:name)
  end

  defp topic(cap, event), do: "#{cap}:#{event}"
end
