defmodule PartitionProvisionerTest do
  use ExUnit.Case, async: true

  test "prefix/1 builds partition schema name" do
    assert PartitionProvisioner.prefix("sk") == "partition_sk"
  end

  test "provision rejects invalid partition id" do
    assert_raise ArgumentError, fn ->
      PartitionProvisioner.provision("BAD-ID", [:issues_cap])
    end
  end

  test "deprovision without confirm raises" do
    assert_raise ArgumentError, fn ->
      PartitionProvisioner.deprovision("sk")
    end
  end
end
