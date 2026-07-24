defmodule Tracms.Repo.Migrations.AddGoogleFormIdsToTrainingActivities do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :registration_form_id, :string
      add :attendance_form_id, :string
    end
  end
end
