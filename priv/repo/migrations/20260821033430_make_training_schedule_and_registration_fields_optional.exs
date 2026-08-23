defmodule Tracms.Repo.Migrations.MakeTrainingScheduleAndRegistrationFieldsOptional do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      modify :starts_on, :date, null: true
      modify :ends_on, :date, null: true
      modify :total_hours, :integer, null: true
      modify :start_time, :time, null: true
      modify :end_time, :time, null: true
      modify :max_capacity, :integer, null: true
      modify :registration_opens_on, :date, null: true
      modify :registration_deadline, :utc_datetime, null: true
    end
  end
end
