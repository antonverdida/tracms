defmodule Tracms.Repo.Migrations.AddTrainingReminderDeliveryConstraint do
  use Ecto.Migration

  def change do
    create unique_index(:notification_deliveries, [:type, :registration_id])
  end
end
