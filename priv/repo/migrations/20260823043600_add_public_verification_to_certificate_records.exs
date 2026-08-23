defmodule Tracms.Repo.Migrations.AddPublicVerificationToCertificateRecords do
  use Ecto.Migration

  def up do
    alter table(:certificate_records) do
      add :verification_code, :string
      add :verification_status, :string, null: false, default: "active"
    end

    # Backfill existing issued certificates with opaque public verification codes.
    execute("""
    UPDATE certificate_records
    SET verification_code = md5(id::text || clock_timestamp()::text || random()::text)
    WHERE verification_code IS NULL
    """)

    alter table(:certificate_records) do
      modify :verification_code, :string, null: false
    end

    create unique_index(:certificate_records, [:verification_code])
    create index(:certificate_records, [:verification_status])
  end

  def down do
    drop index(:certificate_records, [:verification_status])
    drop unique_index(:certificate_records, [:verification_code])

    alter table(:certificate_records) do
      remove :verification_status
      remove :verification_code
    end
  end
end
