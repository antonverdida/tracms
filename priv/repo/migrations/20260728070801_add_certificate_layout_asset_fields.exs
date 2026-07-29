defmodule Tracms.Repo.Migrations.AddCertificateLayoutAssetFields do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add_if_not_exists :asset_path, :string
      add_if_not_exists :asset_name, :string
      add_if_not_exists :asset_content_type, :string
    end
  end
end
