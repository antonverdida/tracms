defmodule Tracms.Repo.Migrations.AddTrainingRecordFieldsToTrainingActivities do
  use Ecto.Migration

  def change do
    alter table(:training_activities) do
      add :training_type, :string
      add :objectives, :text
      add :total_hours, :integer
      add :venue_address, :string
      add :target_participants, :text
      add :participant_qualification, :text
      add :registration_opens_on, :date
      add :attendance_monitoring_method, :string
      add :certificate_type, :string
    end

    execute("""
    UPDATE training_activities
    SET
      training_type = COALESCE(training_type, 'Capacity Building Training'),
      objectives = COALESCE(objectives, description),
      total_hours = COALESCE(total_hours, ((ends_on - starts_on) + 1) * 8),
      venue_address = COALESCE(venue_address, venue),
      target_participants = COALESCE(target_participants, 'DepEd personnel'),
      participant_qualification = COALESCE(
        participant_qualification,
        'Must be endorsed by the appropriate office or school head.'
      ),
      registration_opens_on = COALESCE(registration_opens_on, starts_on - 14),
      attendance_monitoring_method = COALESCE(
        attendance_monitoring_method,
        'QR Code and Manual Verification'
      ),
      certificate_type = COALESCE(certificate_type, 'Certificate of Participation')
    """)

    alter table(:training_activities) do
      modify :training_type, :string, null: false
      modify :objectives, :text, null: false
      modify :total_hours, :integer, null: false
      modify :venue_address, :string, null: false
      modify :target_participants, :text, null: false
      modify :participant_qualification, :text, null: false
      modify :registration_opens_on, :date, null: false
      modify :attendance_monitoring_method, :string, null: false
      modify :certificate_type, :string, null: false
    end
  end
end
