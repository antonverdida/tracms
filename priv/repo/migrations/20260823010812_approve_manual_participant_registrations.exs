defmodule Tracms.Repo.Migrations.ApproveManualParticipantRegistrations do
  use Ecto.Migration

  def up do
    execute """
    UPDATE registrations
    SET status = 'approved', reviewed_at = COALESCE(reviewed_at, NOW())
    WHERE manual_participant_name IS NOT NULL
      AND status = 'submitted'
    """
  end

  def down do
    :ok
  end
end
