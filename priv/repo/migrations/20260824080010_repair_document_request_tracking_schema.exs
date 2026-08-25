defmodule Tracms.Repo.Migrations.RepairDocumentRequestTrackingSchema do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE IF NOT EXISTS document_requests (
      id uuid PRIMARY KEY, request_number varchar NOT NULL, document_type varchar NOT NULL,
      purpose text NOT NULL, requested_on date NOT NULL, status varchar NOT NULL DEFAULT 'pending',
      requester_id uuid NOT NULL REFERENCES users(id), approved_by_id uuid REFERENCES users(id),
      inserted_at timestamp(0) NOT NULL, updated_at timestamp(0) NOT NULL
    )
    """)

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS document_requests_request_number_index ON document_requests (request_number)"
    )

    execute(
      "CREATE INDEX IF NOT EXISTS document_requests_requester_id_index ON document_requests (requester_id)"
    )

    execute("""
    CREATE TABLE IF NOT EXISTS document_controls (
      id uuid PRIMARY KEY, document_request_id uuid NOT NULL REFERENCES document_requests(id) ON DELETE CASCADE,
      document_code varchar NOT NULL, document_title varchar NOT NULL, revision_number varchar NOT NULL DEFAULT '00',
      effectivity_date date NOT NULL, status varchar NOT NULL DEFAULT 'active',
      created_by_id uuid NOT NULL REFERENCES users(id), approved_by_id uuid REFERENCES users(id),
      inserted_at timestamp(0) NOT NULL, updated_at timestamp(0) NOT NULL
    )
    """)

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS document_controls_document_request_id_index ON document_controls (document_request_id)"
    )

    execute(
      "CREATE UNIQUE INDEX IF NOT EXISTS document_controls_document_code_index ON document_controls (document_code)"
    )

    execute("""
    CREATE TABLE IF NOT EXISTS document_revision_histories (
      id uuid PRIMARY KEY, document_control_id uuid NOT NULL REFERENCES document_controls(id) ON DELETE CASCADE,
      old_revision varchar, new_revision varchar NOT NULL, changes_made text NOT NULL, effectivity_date date NOT NULL,
      modified_by_id uuid NOT NULL REFERENCES users(id), inserted_at timestamp(0) NOT NULL, updated_at timestamp(0) NOT NULL
    )
    """)

    execute(
      "CREATE INDEX IF NOT EXISTS document_revision_histories_document_control_id_index ON document_revision_histories (document_control_id)"
    )
  end

  def down, do: :ok
end
