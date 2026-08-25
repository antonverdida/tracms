defmodule Tracms.Repo.Migrations.AddUsernameToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :username, :string
    end

    execute("""
    UPDATE users
    SET username = CASE
      WHEN lower(email) IN ('admin@tracms.local', 'admin@tracms.gov.ph') THEN 'admin'
      ELSE 'user-' || left(replace(id::text, '-', ''), 12)
    END
    """)

    alter table(:users) do
      modify :username, :string, null: false
    end

    create unique_index(:users, [:username])
  end

  def down do
    drop unique_index(:users, [:username])

    alter table(:users) do
      remove :username
    end
  end
end
