defmodule CapabilityRegistryTest do
  use ExUnit.Case, async: true

  test "start_capability returns unknown_capability when name not in manifest" do
    assert {:error, :unknown_capability} =
             CapabilityRegistry.start_capability(:not_listed_anywhere_cap)
  end
end
