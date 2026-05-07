defmodule PartitionProvisioner do
  @moduledoc false

  alias EsKernel.Repo

  def prefix(partition_id) when is_binary(partition_id) do
    "partition_" <> sanitize_id!(partition_id)
  end

  def provision(partition_id, caps) when is_binary(partition_id) and is_list(caps) do
    _ = sanitize_id!(partition_id)
    schema_name = prefix(partition_id)
    manifest = Caps.load!()
    allowed = Caps.capability_names_set(manifest)

    Enum.each(caps, fn cap ->
      unless MapSet.member?(allowed, cap) do
        raise ArgumentError, "capability #{inspect(cap)} not listed in manifest"
      end
    end)

    Repo.transaction(fn ->
      :ok = ddl_create_schema(schema_name)

      _ =
        Repo.insert_all("partition_events", [
          %{
            partition_id: partition_id,
            capability: nil,
            event: "provisioned",
            actor_id: nil
          }
        ])

      # Future: run per-capability migrations for `caps` inside schema_name.
      :ok
    end)
    |> case do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def add_capability(partition_id, cap) when is_binary(partition_id) and is_atom(cap) do
    _ = sanitize_id!(partition_id)

    manifest = Caps.load!()

    if MapSet.member?(Caps.capability_names_set(manifest), cap) do
      _ =
        Repo.insert_all("partition_events", [
          %{
            partition_id: partition_id,
            capability: Atom.to_string(cap),
            event: "cap_added",
            actor_id: nil
          }
        ])

      :ok
    else
      {:error, :not_in_caps_lock}
    end
  end

  def deprovision(partition_id, opts \\ []) when is_binary(partition_id) do
    unless Keyword.get(opts, :confirm, false) do
      raise ArgumentError, "deprovision/2 requires confirm: true"
    end

    _ = sanitize_id!(partition_id)
    {:error, :has_active_data}
  end

  defp sanitize_id!(partition_id) do
    if Regex.match?(~r/^[a-z0-9_]+$/, partition_id) do
      partition_id
    else
      raise ArgumentError,
            "partition_id must match ^[a-z0-9_]+$, got #{inspect(partition_id)}"
    end
  end

  defp ddl_create_schema(schema) do
    case Repo.query(~s(CREATE SCHEMA IF NOT EXISTS "#{schema}")) do
      {:ok, _} -> :ok
      {:error, err} -> Repo.rollback(err)
    end
  end
end
