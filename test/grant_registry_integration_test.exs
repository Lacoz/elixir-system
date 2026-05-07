defmodule GrantRegistryIntegrationTest do
  use KernelIntegrationCase

  import Ecto.Query

  setup do
    principal = "user:int_test_#{System.unique_integer([:positive])}"

    on_exit(fn ->
      EsKernel.Repo.delete_all(from(ge in "grant_events", where: ge.principal_id == ^principal))
    end)

    {:ok, principal: principal}
  end

  test "grant then authorize flow", %{principal: principal} do
    assert :ok =
             GrantRegistry.grant(principal, :issues_cap, ["sk"], [:read], granted_by: "hq:test")

    assert :allow = GrantRegistry.authorize(principal, :issues_cap, :read, "sk")
    assert {:deny, :no_grant} = GrantRegistry.authorize(principal, :issues_cap, :write, "sk")
  end

  test "grant rejects capability absent from manifest", %{principal: principal} do
    assert {:error, :not_in_caps_lock} =
             GrantRegistry.grant(principal, :ghost_cap, ["sk"], [:read], [])
  end
end
