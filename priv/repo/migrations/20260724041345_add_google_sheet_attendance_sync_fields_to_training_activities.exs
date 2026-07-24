defmodule Tracms.Repo.Migrations.AddGoogleSheetAttendanceSyncFieldsToTrainingActivities do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :attendance_sheet_id, :string
      add :attendance_sheet_range, :string
      add :attendance_sheet_last_synced_at, :utc_datetime
    end
  end
end
