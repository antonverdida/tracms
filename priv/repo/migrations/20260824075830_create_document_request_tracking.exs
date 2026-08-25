defmodule Tracms.Repo.Migrations.CreateDocumentRequestTracking do
  use Ecto.Migration

  def change do
    create table(:document_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :request_number, :string, null: false
      add :document_type, :string, null: false
      add :purpose, :text, null: false
      add :requested_on, :date, null: false
      add :status, :string, null: false, default: "pending"
      add :requester_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :approved_by_id, references(:users, type: :binary_id, on_delete: :restrict)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:document_requests, [:request_number])
    create index(:document_requests, [:requester_id])
    create index(:document_requests, [:status])

    create table(:document_controls, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :document_request_id,
          references(:document_requests, type: :binary_id, on_delete: :delete_all),
          null: false

      add :document_code, :string, null: false
      add :document_title, :string, null: false
      add :revision_number, :string, null: false, default: "00"
      add :effectivity_date, :date, null: false
      add :status, :string, null: false, default: "active"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :approved_by_id, references(:users, type: :binary_id, on_delete: :restrict)
      timestamps(type: :utc_datetime)
    end

    create unique_index(:document_controls, [:document_request_id])
    create unique_index(:document_controls, [:document_code])

    create table(:document_revision_histories, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :document_control_id,
          references(:document_controls, type: :binary_id, on_delete: :delete_all),
          null: false

      add :old_revision, :string
      add :new_revision, :string, null: false
      add :changes_made, :text, null: false
      add :effectivity_date, :date, null: false
      add :modified_by_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:document_revision_histories, [:document_control_id])
  end
end
