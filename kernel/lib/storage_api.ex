defmodule CapabilityStorage do
  @moduledoc false

  import Ecto.Query

  def repo(cap_name, _partition_id) when is_atom(cap_name) do
    _ = namespace(cap_name)
    EsKernel.Repo
  end

  def namespace(cap_name) when is_atom(cap_name) do
    cap_name
    |> Atom.to_string()
    |> String.replace_suffix("_cap", "")
    |> validated_ident!(:namespace)
  end

  def prefix(partition_id) when is_binary(partition_id) do
    PartitionProvisioner.prefix(partition_id)
  end

  def query(cap_name, partitions, opts) when is_atom(cap_name) and is_list(partitions) do
    unless Keyword.fetch!(opts, :read_only) do
      raise ArgumentError, "CapabilityStorage.query/3 requires read_only: true"
    end

    table =
      Keyword.fetch!(opts, :from)
      |> to_string()
      |> validated_ident!(:table)

    tab = "#{namespace(cap_name)}_#{table}"

    case partitions do
      [] ->
        raise ArgumentError, "partitions cannot be empty"

      [first | rest] ->
        Enum.reduce(rest, fragment_select(tab, first), fn partition, acc ->
          union_all(acc, ^fragment_select(tab, partition))
        end)
    end
  end

  defp validated_ident!(str, _) when str in [nil, ""], do: raise(ArgumentError, "empty identifier")

  defp validated_ident!(str, _ctx) do
    if Regex.match?(~r/^[a-z0-9_]+$/, str), do: str, else: raise(ArgumentError, "invalid identifier #{inspect(str)}")
  end

  defp fragment_select(tab, partition_id) do
    validated_ident!(tab, :table)

    pref =
      PartitionProvisioner.prefix(partition_id)
      |> validated_ident!(:schema)

    sql =
      IO.iodata_to_binary(["SELECT * FROM \"", pref, "\".\"", tab, "\" AS __kern"])

    from(fr in fragment(^sql))
  end
end
