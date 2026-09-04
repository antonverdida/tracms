defmodule Tracms.Repo.Migrations.CreateNotificationDeliveries do
  use Ecto.Migration

  def change do
    create table(:notification_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :payload, :map, null: false, default: %{}
      add :delivered_at, :utc_datetime
      add :failed_at, :utc_datetime

      add :recipient_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :registration_id, references(:registrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :training_activity_id,
          references(:training_activities, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:notification_deliveries, [:recipient_user_id, :inserted_at])
    create index(:notification_deliveries, [:registration_id])
    create index(:notification_deliveries, [:status])
  end
end
