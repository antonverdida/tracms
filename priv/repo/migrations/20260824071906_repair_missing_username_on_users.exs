defmodule Tracms.Repo.Migrations.RepairMissingUsernameOnUsers do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'users'
          AND column_name = 'username'
      ) THEN
        ALTER TABLE users ADD COLUMN username varchar;
      END IF;
    END $$;
    """)

    execute("""
    UPDATE users
    SET username = CASE
      WHEN lower(email) IN ('admin@tracms.local', 'admin@tracms.gov.ph') THEN 'admin'
      ELSE 'user-' || left(replace(id::text, '-', ''), 12)
    END
    WHERE username IS NULL
    """)

    execute("ALTER TABLE users ALTER COLUMN username SET NOT NULL")
    execute("CREATE UNIQUE INDEX IF NOT EXISTS users_username_index ON users (username)")
  end

  def down do
    # The original migration owns this schema change. This repair is intentionally idempotent.
    :ok
  end
end
