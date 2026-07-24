defmodule Tracms.Repo.Migrations.AddGoogleSheetSyncFieldsToTrainingActivities do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :registration_sheet_id, :string
      add :registration_sheet_range, :string
      add :registration_sheet_last_synced_at, :utc_datetime
    end
  end
end
