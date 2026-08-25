defmodule Tracms.Repo.Migrations.MakeTrainingNarrativeFieldsOptional do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      modify :description, :text, null: true
      modify :objectives, :text, null: true
      modify :target_participants, :text, null: true
      modify :participant_qualification, :text, null: true
    end
  end
end
