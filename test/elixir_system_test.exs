defmodule ElixirSystemTest do
  use ExUnit.Case

  test "es_kernel OTP application loads" do
    assert {:ok, _} = Application.ensure_all_started(:es_kernel)
  end
end
