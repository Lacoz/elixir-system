defmodule EsKernel.Repo.Migrations.CreateAuditTables do
  @moduledoc false
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto", "")

    create table(:partition_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:partition_id, :string, null: false)
      add(:capability, :string)
      add(:event, :string, null: false)
      add(:actor_id, :string)
      add(:inserted_at, :utc_datetime_usec, default: fragment("timezone('utc', now())"), null: false)
    end

    create table(:grant_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()"))
      add(:principal_id, :string, null: false)
      add(:capability, :string, null: false)
      add(:partitions, {:array, :string}, null: false)
      add(:permissions, {:array, :string}, null: false)
      add(:event, :string, null: false)
      add(:valid_until, :utc_datetime_usec)
      add(:granted_by, :string)
      add(:beads_ref, :string)
      add(:inserted_at, :utc_datetime_usec, default: fragment("timezone('utc', now())"), null: false)
    end
  end

  def down do
    drop(table(:grant_events))
    drop(table(:partition_events))
  end
end
