defmodule Tracms.Repo.Migrations.AddExternalCollectionUrlsToTrainingActivities do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :registration_form_url, :string
      add :attendance_form_url, :string
    end
  end
end
