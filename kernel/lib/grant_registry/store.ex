defmodule GrantRegistry.Store do
  @moduledoc false

  import Ecto.Query

  alias EsKernel.Repo

  def reload do
    rows =
      from(ge in "grant_events",
        order_by: [asc: ge.inserted_at],
        select: %{
          principal_id: ge.principal_id,
          capability: ge.capability,
          partitions: ge.partitions,
          permissions: ge.permissions,
          event: ge.event,
          valid_until: ge.valid_until,
          inserted_at: ge.inserted_at
        }
      )
      |> Repo.all()

    by_principal =
      Enum.reduce(rows, %{}, fn row, acc ->
        apply_event_row(acc, row)
      end)

    %{by_principal: by_principal}
  end

  def persist!(event, principal_id, cap, partitions, permissions, opts) when is_list(opts) do
    parts = encode_partitions(partitions)
    perms = Enum.map(permissions, &Atom.to_string/1)

    Repo.insert_all("grant_events", [
      %{
        principal_id: principal_id,
        capability: Atom.to_string(cap),
        partitions: parts,
        permissions: perms,
        event: event,
        valid_until: Keyword.get(opts, :valid_until),
        granted_by: Keyword.get(opts, :granted_by, "system:kernel"),
        beads_ref: Keyword.get(opts, :beads_ref)
      }
    ])
  end

  defp apply_event_row(acc, %{event: "granted"} = row) do
    g = to_grant(row)
    Map.update(acc, g.principal_id, [g], fn list -> [g | list] end)
  end

  defp apply_event_row(acc, %{event: ev} = row) when ev in ["revoked", "expired"] do
    p = row.principal_id
    cap = String.to_atom(row.capability)
    target = decode_partitions(row.partitions)

    Map.update(acc, p, [], fn list ->
      Enum.reject(list, fn g ->
        g.capability == cap && partitions_equal?(g.partitions, target)
      end)
    end)
  end

  defp apply_event_row(acc, _), do: acc

  defp partitions_equal?(:all, :all), do: true
  defp partitions_equal?(a, b) when is_list(a) and is_list(b), do: a == b
  defp partitions_equal?(_, _), do: false

  defp to_grant(row) do
    %Grant{
      principal_id: row.principal_id,
      capability: String.to_atom(row.capability),
      partitions: decode_partitions(row.partitions),
      permissions: Enum.map(row.permissions, &String.to_atom/1),
      valid_until: row.valid_until,
      inserted_at: row.inserted_at
    }
  end

  defp decode_partitions(["*"]), do: :all
  defp decode_partitions(list) when is_list(list), do: list

  defp encode_partitions(:all), do: ["*"]
  defp encode_partitions(list) when is_list(list), do: list
end
