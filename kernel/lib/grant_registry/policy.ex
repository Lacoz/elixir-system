defmodule GrantRegistry.Policy do
  @moduledoc false

  def authorize(principal_id, cap, action, partition_id, st) do
    manifest = Caps.load!()

    unless MapSet.member?(Caps.capability_names_set(manifest), cap) do
      {:deny, :no_capability}
    else
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      grants = Map.get(st.by_principal, principal_id, [])

      case Enum.find(grants, fn g ->
             g.capability == cap && partition_allowed?(g.partitions, partition_id) &&
               action in g.permissions
           end) do
        nil -> {:deny, :no_grant}
        g -> if(expired?(g, now), do: {:deny, :grant_expired}, else: :allow)
      end
    end
  end

  defp partition_allowed?(:all, _), do: true

  defp partition_allowed?(list, partition_id)
       when is_list(list) and is_binary(partition_id),
       do: partition_id in list

  defp partition_allowed?(_, _), do: false

  defp expired?(%Grant{valid_until: nil}, _), do: false
  defp expired?(%Grant{valid_until: vu}, now), do: DateTime.compare(vu, now) != :gt
end
