defmodule Tracms.Repo.Migrations.CreateExternalRegistrationSubmissions do
  use Ecto.Migration

  def change do
    create table(:external_registration_submissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :full_name, :string, null: false
      add :email, :string, null: false
      add :employee_number, :string
      add :office_name, :string
      add :source_reference, :string
      add :special_requirements, :text
      add :review_notes, :text
      add :status, :string, null: false
      add :submitted_at, :utc_datetime, null: false
      add :reviewed_at, :utc_datetime

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :matched_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :imported_registration_id,
          references(:registrations, type: :binary_id, on_delete: :nilify_all)

      add :reviewer_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:external_registration_submissions, [:training_activity_id])
    create index(:external_registration_submissions, [:matched_user_id])
    create index(:external_registration_submissions, [:imported_registration_id])
    create index(:external_registration_submissions, [:status])
  end
end
