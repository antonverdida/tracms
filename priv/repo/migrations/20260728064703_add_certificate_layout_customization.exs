defmodule Tracms.Repo.Migrations.AddCertificateLayoutCustomization do
  use Ecto.Migration

  def change do
    create table(:certificate_layout_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scope_key, :string, null: false, default: "default"
      add :layout_style, :string, null: false, default: "classic"
      add :accent_color, :string, null: false, default: "deped_blue"
      add :header_title, :string, null: false, default: "Department of Education"
      add :header_subtitle, :string, null: false, default: "Region IX"
      add :body_intro, :text, null: false, default: "This certifies that"

      add :completion_statement, :text,
        null: false,
        default: "successfully completed the authorized learning and development activity"

      add :signature_label, :string, null: false, default: "Authorized Issuing Officer"
      add :issuing_office_label, :string, null: false, default: "DepEd Region IX"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:certificate_layout_settings, [:scope_key])

    alter table(:training_activities) do
      add :certificate_layout_style, :string
      add :certificate_accent_color, :string
      add :certificate_header_title, :string
      add :certificate_header_subtitle, :string
      add :certificate_body_intro, :text
      add :certificate_completion_statement, :text
      add :certificate_signature_label, :string
      add :certificate_issuing_office_label, :string
    end
  end
end
