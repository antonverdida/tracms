defmodule Tracms.Repo.Migrations.AddCertificateSizeToCertificateLayoutSettings do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add :certificate_size, :string, default: "a4_landscape"
    end
  end
end
