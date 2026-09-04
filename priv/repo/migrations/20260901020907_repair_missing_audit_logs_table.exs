defmodule Tracms.Repo.Migrations.RepairMissingAuditLogsTable do
  use Ecto.Migration

  # A prior development database recorded the original migration without retaining its table.
  # This repair is intentionally idempotent so healthy databases remain unchanged.
  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS audit_logs (
      id uuid PRIMARY KEY,
      action varchar NOT NULL,
      entity_type varchar NOT NULL,
      entity_id varchar NOT NULL,
      metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
      actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
      training_activity_id uuid REFERENCES training_activities(id) ON DELETE SET NULL,
      inserted_at timestamp(0) NOT NULL
    )
    """)

    execute(
      "CREATE INDEX IF NOT EXISTS audit_logs_training_activity_id_inserted_at_index ON audit_logs (training_activity_id, inserted_at)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS audit_logs_actor_user_id_inserted_at_index ON audit_logs (actor_user_id, inserted_at)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS audit_logs_entity_type_entity_id_inserted_at_index ON audit_logs (entity_type, entity_id, inserted_at)"
    )

    execute("CREATE INDEX IF NOT EXISTS audit_logs_action_index ON audit_logs (action)")
  end

  def down, do: :ok
end
