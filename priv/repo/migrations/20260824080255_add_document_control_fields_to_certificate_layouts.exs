defmodule Tracms.Repo.Migrations.AddDocumentControlFieldsToCertificateLayouts do
  use Ecto.Migration

  def change do
    alter table(:certificate_layout_settings) do
      add :document_reference_code, :string, null: false, default: "RO-ORD-F018"
      add :revision_number, :string, null: false, default: "00"
      add :effectivity_date, :date, null: false, default: "2025-02-20"
    end
  end
end
