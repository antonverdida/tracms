defmodule Tracms.Repo.Migrations.AddCertificateLayoutAssetColumns do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add_if_not_exists :asset_data, :binary
      add_if_not_exists :asset_size, :integer
    end
  end
end
