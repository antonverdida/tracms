defmodule Tracms.Repo.Migrations.ExtendTrainingManagementFields do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :resource_speaker, :string
      add :start_time, :time
      add :end_time, :time
    end
  end
end
