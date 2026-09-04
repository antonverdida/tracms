defmodule Tracms.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :string, null: false
      add :metadata, :map, null: false, default: %{}
      add :actor_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:training_activity_id, :inserted_at])
    create index(:audit_logs, [:actor_user_id, :inserted_at])
    create index(:audit_logs, [:entity_type, :entity_id, :inserted_at])
    create index(:audit_logs, [:action])
  end
end
