defmodule ElixirSystemTest do
  use ExUnit.Case

  test "host module loads" do
    assert ElixirSystem.__coverage_anchor__() == :ok
  end

  test "kernel compiler produced core modules (no OTP boot — DB optional)" do
    for mod <- [
          EsKernel.Repo,
          GrantRegistry.Store,
          GrantRegistry.Server,
          PartitionProvisioner,
          CapabilityStorage,
          CapabilityBus,
          CapabilityHost,
          CapabilityRegistry
        ] do
      assert {:module, _} = Code.ensure_loaded(mod)
    end
  end
end
