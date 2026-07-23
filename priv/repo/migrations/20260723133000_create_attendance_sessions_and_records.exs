defmodule Tracms.Repo.Migrations.CreateAttendanceSessionsAndRecords do
  use Ecto.Migration

  def change do
    create table(:attendance_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :session_date, :date, null: false
      add :starts_at, :time, null: false
      add :ends_at, :time, null: false
      add :status, :string, null: false, default: "draft"

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :opened_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :closed_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:attendance_sessions, [:training_activity_id])
    create index(:attendance_sessions, [:status])
    create unique_index(:attendance_sessions, [:training_activity_id, :session_date, :name])

    create table(:attendance_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false
      add :notes, :text
      add :marked_at, :utc_datetime, null: false

      add :attendance_session_id,
          references(:attendance_sessions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :registration_id, references(:registrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :marked_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:attendance_records, [:attendance_session_id])
    create index(:attendance_records, [:registration_id])
    create index(:attendance_records, [:status])
    create unique_index(:attendance_records, [:attendance_session_id, :registration_id])
  end
end
