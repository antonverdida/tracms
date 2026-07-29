defmodule Tracms.Repo.Migrations.RepairCertificateLayoutCustomizationSchema do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:certificate_layout_settings, primary_key: false) do
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

    create_if_not_exists unique_index(:certificate_layout_settings, [:scope_key])

    alter table(:training_activities) do
      add_if_not_exists :certificate_layout_style, :string
      add_if_not_exists :certificate_accent_color, :string
      add_if_not_exists :certificate_header_title, :string
      add_if_not_exists :certificate_header_subtitle, :string
      add_if_not_exists :certificate_body_intro, :text
      add_if_not_exists :certificate_completion_statement, :text
      add_if_not_exists :certificate_signature_label, :string
      add_if_not_exists :certificate_issuing_office_label, :string
    end
  end
end
