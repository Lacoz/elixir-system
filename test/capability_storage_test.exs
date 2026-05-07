defmodule CapabilityStorageTest do
  use ExUnit.Case, async: true

  test "namespace strips _cap suffix" do
    assert CapabilityStorage.namespace(:issues_cap) == "issues"
    assert CapabilityStorage.namespace(:billing_cap) == "billing"
  end

  test "query/3 rejects non-read_only" do
    assert_raise ArgumentError, fn ->
      CapabilityStorage.query(:issues_cap, ["sk"], from: "items", read_only: false)
    end
  end

  test "query/3 rejects empty partitions" do
    assert_raise ArgumentError, fn ->
      CapabilityStorage.query(:issues_cap, [], from: "items", read_only: true)
    end
  end
end
