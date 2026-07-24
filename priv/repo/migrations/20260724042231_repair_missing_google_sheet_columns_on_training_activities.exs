defmodule Tracms.Repo.Migrations.RepairMissingGoogleSheetColumnsOnTrainingActivities do
  use Ecto.Migration

  def change do
    execute(
      """
      ALTER TABLE training_activities
      ADD COLUMN IF NOT EXISTS registration_sheet_id varchar,
      ADD COLUMN IF NOT EXISTS registration_sheet_range varchar,
      ADD COLUMN IF NOT EXISTS registration_sheet_last_synced_at timestamp(0) with time zone,
      ADD COLUMN IF NOT EXISTS attendance_sheet_id varchar,
      ADD COLUMN IF NOT EXISTS attendance_sheet_range varchar,
      ADD COLUMN IF NOT EXISTS attendance_sheet_last_synced_at timestamp(0) with time zone
      """,
      """
      ALTER TABLE training_activities
      DROP COLUMN IF EXISTS attendance_sheet_last_synced_at,
      DROP COLUMN IF EXISTS attendance_sheet_range,
      DROP COLUMN IF EXISTS attendance_sheet_id,
      DROP COLUMN IF EXISTS registration_sheet_last_synced_at,
      DROP COLUMN IF EXISTS registration_sheet_range,
      DROP COLUMN IF EXISTS registration_sheet_id
      """
    )
  end
end
