defmodule CapabilityBusTest do
  use ExUnit.Case, async: false

  setup do
    {:ok, _} = Application.ensure_all_started(:telemetry)
    {:ok, _} = Application.ensure_all_started(:phoenix_pubsub)

    pub = :"pubsub_test_#{System.unique_integer([:positive])}"

    Application.put_env(:es_kernel, :capability_pubsub_options, name: pub)
    start_supervised!({Phoenix.PubSub, name: pub})
    :ok
  end

  test "emit delivers payloads to subscribers" do
    :ok = CapabilityBus.subscribe(:billing_cap, :"invoice_created:v1")

    payload = %{id: "inv_1", amount: Decimal.new("1.00")}
    partition = "partition_sk"

    :ok =
      CapabilityBus.emit(:billing_cap, :"invoice_created:v1", payload, partition)

    assert_receive {:cap_event, :billing_cap, :"invoice_created:v1", ^partition, ^payload}
  end
end
