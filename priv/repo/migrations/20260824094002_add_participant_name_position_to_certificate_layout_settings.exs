defmodule Tracms.Repo.Migrations.AddParticipantNamePositionToCertificateLayoutSettings do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add :participant_name_position, :float, null: false, default: 39.0
      add :participant_name_position_source, :string, null: false, default: "fallback"
    end
  end
end
