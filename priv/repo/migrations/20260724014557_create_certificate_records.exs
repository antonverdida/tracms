defmodule Tracms.Repo.Migrations.CreateCertificateRecords do
  use Ecto.Migration

  def change do
    create table(:certificate_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :certificate_number, :string, null: false
      add :certificate_type, :string, null: false
      add :issued_on, :date, null: false
      add :delivery_status, :string, null: false, default: "available"
      add :emailed_at, :utc_datetime
      add :downloaded_at, :utc_datetime

      add :registration_id, references(:registrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :issued_by_user_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:certificate_records, [:registration_id])
    create unique_index(:certificate_records, [:certificate_number])
    create index(:certificate_records, [:issued_on])
    create index(:certificate_records, [:delivery_status])
    create index(:certificate_records, [:issued_by_user_id])
  end
end
