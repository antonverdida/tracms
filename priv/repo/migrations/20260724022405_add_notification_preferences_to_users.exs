defmodule Tracms.Repo.Migrations.AddNotificationPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :notification_preferences, :map,
        null: false,
        default: %{
          training_announcements: true,
          registration_updates: true,
          certificate_availability: true,
          system_announcements: true
        }
    end
  end
end
