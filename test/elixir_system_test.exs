defmodule ElixirSystemTest do
  use ExUnit.Case

  test "kernel compiler produced core modules (no OTP boot — DB optional)" do
    for mod <- [
          EsKernel.Repo,
          GrantRegistry.Store,
          GrantRegistry.Server,
          PartitionProvisioner,
          CapabilityStorage
        ] do
      assert {:module, _} = Code.ensure_loaded(mod)
    end
  end
end
