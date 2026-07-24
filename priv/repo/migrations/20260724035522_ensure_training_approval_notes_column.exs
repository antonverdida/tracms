defmodule Tracms.Repo.Migrations.EnsureTrainingApprovalNotesColumn do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE training_approvals
    ADD COLUMN IF NOT EXISTS notes text
    """)
  end

  def down do
    execute("""
    ALTER TABLE training_approvals
    DROP COLUMN IF EXISTS notes
    """)
  end
end
