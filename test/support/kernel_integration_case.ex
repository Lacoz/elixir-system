defmodule KernelIntegrationCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration
    end
  end

  setup do
    Application.ensure_all_started(:logger)

    case Application.ensure_all_started(:es_kernel) do
      {:ok, _} ->
        checkout_grant_allow()

      {:error, {:already_started, _}} ->
        checkout_grant_allow()

      {:error, reason} ->
        flunk("PostgreSQL / es_kernel required for integration tests: #{inspect(reason)}")
    end
  end

  defp checkout_grant_allow do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EsKernel.Repo)
    pid = Process.whereis(GrantRegistry) || self()
    Ecto.Adapters.SQL.Sandbox.allow(EsKernel.Repo, self(), pid, :infinity)
    :ok
  end
end
