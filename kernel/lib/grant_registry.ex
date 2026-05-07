defmodule GrantRegistry do
  @moduledoc false
  def start_link(opts), do: GrantRegistry.Server.start_link(opts)

  def grants_for(principal_id), do: GrantRegistry.Server.grants_for(principal_id)

  def authorize(principal_id, cap, action, partition_id),
    do: GrantRegistry.Server.authorize(principal_id, cap, action, partition_id)

  def grant(principal_id, cap, partitions, permissions, opts \\ []) do
    GrantRegistry.Server.grant(principal_id, cap, partitions, permissions, opts)
  end

  def revoke(principal_id, cap, partitions) do
    GrantRegistry.Server.revoke(principal_id, cap, partitions)
  end

  def expire_grants(), do: GrantRegistry.Server.expire_grants()
end
