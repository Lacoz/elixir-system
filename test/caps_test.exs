defmodule CapsTest do
  use ExUnit.Case, async: true

  test "capability_names_set collects declared caps" do
    data = %{
      "capability" => [
        %{"name" => "issues_cap"},
        %{"name" => "billing_cap"}
      ]
    }

    set = Caps.capability_names_set(data)
    assert MapSet.equal?(set, MapSet.new([:issues_cap, :billing_cap]))
  end

  test "kernel_min_version defaults when absent" do
    assert Caps.kernel_min_version!(%{}) == Version.parse!("0.0.0")
    assert Caps.kernel_min_version!(%{"kernel_min" => "1.2.3"}) == Version.parse!("1.2.3")
  end
end
