defmodule Tracms.Repo.Migrations.AddTrainingApprovalsAuditTrail do
  use Ecto.Migration

  def change do
    create table(:training_approvals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :actor_role_key, :string, null: false
      add :from_status, :string
      add :to_status, :string, null: false

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :delete_all),
          null: false

      add :acted_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:training_approvals, [:training_activity_id, :inserted_at])
    create index(:training_approvals, [:acted_by_user_id])
    create index(:training_approvals, [:action])
  end
end
