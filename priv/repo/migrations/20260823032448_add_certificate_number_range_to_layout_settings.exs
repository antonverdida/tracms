defmodule Tracms.Repo.Migrations.AddCertificateNumberRangeToLayoutSettings do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add :certificate_number_start, :integer, null: false, default: 1
      add :certificate_number_end, :integer, null: false, default: 999_999
    end
  end
end
