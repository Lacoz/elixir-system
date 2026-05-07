defmodule GrantRegistry.Server do
  @moduledoc false
  use GenServer

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: GrantRegistry)

  def grants_for(principal_id),
    do: GenServer.call(GrantRegistry, {:grants_for, principal_id})

  def authorize(principal_id, cap, action, partition_id),
    do: GenServer.call(GrantRegistry, {:authorize, principal_id, cap, action, partition_id})

  def grant(principal_id, cap, partitions, permissions, opts),
    do: GenServer.call(GrantRegistry, {:grant, principal_id, cap, partitions, permissions, opts})

  def revoke(principal_id, cap, partitions),
    do: GenServer.call(GrantRegistry, {:revoke, principal_id, cap, partitions})

  def expire_grants(), do: GenServer.call(GrantRegistry, :expire_grants)

  @impl true
  def init(_opts), do: {:ok, GrantRegistry.Store.reload()}

  @impl true
  def handle_call({:grants_for, principal_id}, _, st),
    do: {:reply, Map.get(st.by_principal, principal_id, []), st}

  def handle_call({:authorize, principal_id, cap, action, partition_id}, _, st),
    do: {:reply, GrantRegistry.Policy.authorize(principal_id, cap, action, partition_id, st), st}

  def handle_call({:grant, principal_id, cap, partitions, permissions, opts}, _, st) do
    manifest = Caps.load!()

    if MapSet.member?(Caps.capability_names_set(manifest), cap) do
      GrantRegistry.Store.persist!("granted", principal_id, cap, partitions, permissions, opts)
      {:reply, :ok, GrantRegistry.Store.reload()}
    else
      {:reply, {:error, :not_in_caps_lock}, st}
    end
  end

  def handle_call({:revoke, principal_id, cap, partitions}, _, _st) do
    GrantRegistry.Store.persist!("revoked", principal_id, cap, partitions, [], [])
    {:reply, :ok, GrantRegistry.Store.reload()}
  end

  def handle_call(:expire_grants, _, _st) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    st = GrantRegistry.Store.reload()

    st.by_principal
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&grant_expired?(&1, now))
    |> Enum.each(fn g ->
      GrantRegistry.Store.persist!(
        "expired",
        g.principal_id,
        g.capability,
        g.partitions,
        g.permissions,
        []
      )
    end)

    {:reply, :ok, GrantRegistry.Store.reload()}
  end

  defp grant_expired?(%Grant{valid_until: nil}, _), do: false

  defp grant_expired?(%Grant{valid_until: vu}, now),
    do: DateTime.compare(vu, now) != :gt
end
