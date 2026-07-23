defmodule Tracms.Repo.Migrations.CreateTrainingActivities do
  use Ecto.Migration

  def change do
    create table(:training_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text, null: false
      add :category, :string, null: false
      add :organizer, :string, null: false
      add :modality, :string, null: false
      add :venue, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :registration_deadline, :utc_datetime, null: false
      add :max_capacity, :integer, null: false
      add :starts_on, :date, null: false
      add :ends_on, :date, null: false
      add :published_at, :utc_datetime
      add :creator_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :office_id, references(:offices, type: :binary_id, on_delete: :nilify_all)
      add :division_id, references(:divisions, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:training_activities, [:status])
    create index(:training_activities, [:starts_on])
    create index(:training_activities, [:creator_user_id])
    create index(:training_activities, [:office_id])
    create index(:training_activities, [:division_id])
  end
end
