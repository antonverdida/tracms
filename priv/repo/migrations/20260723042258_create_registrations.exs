defmodule Tracms.Repo.Migrations.CreateRegistrations do
  use Ecto.Migration

  def change do
    create table(:registrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "submitted"
      add :special_requirements, :text
      add :review_notes, :text
      add :submitted_at, :utc_datetime, null: false
      add :reviewed_at, :utc_datetime

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :registrant_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :reviewer_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:registrations, [:training_activity_id, :registrant_user_id])
    create index(:registrations, [:status])
    create index(:registrations, [:registrant_user_id])
    create index(:registrations, [:reviewer_user_id])
  end
end
