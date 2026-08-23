defmodule Tracms.Repo.Migrations.AddManualParticipantsToRegistrations do
  use Ecto.Migration

  def change do
    alter table(:registrations) do
      modify :registrant_user_id, :binary_id, null: true

      add :manual_participant_name, :string
      add :manual_participant_email, :string
    end
  end
end
