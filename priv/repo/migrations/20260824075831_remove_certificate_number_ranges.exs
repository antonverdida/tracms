defmodule Tracms.Repo.Migrations.RemoveCertificateNumberRanges do
  use Ecto.Migration

  def up do
    alter table(:certificate_layout_settings) do
      remove :certificate_number_start
      remove :certificate_number_end
    end
  end

  def down do
    alter table(:certificate_layout_settings) do
      add :certificate_number_start, :integer, null: false, default: 1
      add :certificate_number_end, :integer, null: false, default: 999_999
    end
  end
end
