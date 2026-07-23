defmodule Tracms.Repo.Migrations.AddCompletionRulesAndEvaluationSubmissions do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :minimum_attendance_percentage, :integer, null: false, default: 75
      add :evaluation_required, :boolean, null: false, default: false
    end

    create table(:evaluation_submissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :overall_rating, :integer, null: false
      add :feedback, :text
      add :application_plan, :text
      add :submitted_at, :utc_datetime, null: false

      add :registration_id, references(:registrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :submitted_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:evaluation_submissions, [:registration_id])
    create index(:evaluation_submissions, [:submitted_by_user_id])
    create index(:evaluation_submissions, [:submitted_at])
  end
end
