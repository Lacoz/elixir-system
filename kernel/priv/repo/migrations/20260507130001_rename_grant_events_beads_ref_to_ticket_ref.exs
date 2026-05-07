defmodule EsKernel.Repo.Migrations.RenameGrantEventsBeadsRefToTicketRef do
  @moduledoc false
  use Ecto.Migration

  def up do
    rename(table(:grant_events), :beads_ref, to: :ticket_ref)
  end

  def down do
    rename(table(:grant_events), :ticket_ref, to: :beads_ref)
  end
end
