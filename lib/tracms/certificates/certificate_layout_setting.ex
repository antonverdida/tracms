defmodule Tracms.Certificates.CertificateLayoutSetting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @layout_style_options [
    {"Classic", "classic"},
    {"Formal", "formal"},
    {"Modern", "modern"}
  ]

  @accent_color_options [
    {"DepEd Blue", "deped_blue"},
    {"Blue and Gold", "blue_gold"},
    {"Slate Blue", "slate_blue"}
  ]

  @certificate_size_options [
    {"A4 Landscape", "a4_landscape"},
    {"Letter Landscape", "letter_landscape"},
    {"Legal Landscape", "legal_landscape"}
  ]

  @editable_fields [
    :certificate_size,
    :layout_style,
    :accent_color,
    :header_title,
    :header_subtitle,
    :body_intro,
    :completion_statement,
    :signature_label,
    :issuing_office_label,
    :document_reference_code,
    :revision_number,
    :effectivity_date,
    :participant_name_position
  ]

  @asset_fields [
    :asset_path,
    :asset_name,
    :asset_content_type,
    :asset_data,
    :asset_size,
    :participant_name_position_source
  ]

  @defaults %{
    scope_key: "default",
    certificate_size: "a4_landscape",
    layout_style: "classic",
    accent_color: "deped_blue",
    header_title: "Department of Education",
    header_subtitle: "Region IX",
    body_intro: "This certifies that",
    completion_statement:
      "successfully completed the authorized learning and development activity",
    signature_label: "Authorized Issuing Officer",
    issuing_office_label: "DepEd Region IX",
    asset_path: nil,
    asset_name: nil,
    asset_content_type: nil,
    asset_data: nil,
    asset_size: nil,
    document_reference_code: "RO-ORD-F018",
    revision_number: "00",
    effectivity_date: ~D[2025-02-20],
    participant_name_position: 39.0,
    participant_name_position_source: "fallback"
  }

  @field_aliases %{
    certificate_size: [:certificate_size],
    layout_style: [:layout_style, :certificate_layout_style],
    accent_color: [:accent_color, :certificate_accent_color],
    header_title: [:header_title, :certificate_header_title],
    header_subtitle: [:header_subtitle, :certificate_header_subtitle],
    body_intro: [:body_intro, :certificate_body_intro],
    completion_statement: [:completion_statement, :certificate_completion_statement],
    signature_label: [:signature_label, :certificate_signature_label],
    issuing_office_label: [:issuing_office_label, :certificate_issuing_office_label],
    document_reference_code: [:document_reference_code],
    revision_number: [:revision_number],
    effectivity_date: [:effectivity_date],
    participant_name_position: [:participant_name_position]
  }

  schema "certificate_layout_settings" do
    field :scope_key, :string, default: "default"
    field :certificate_size, :string, default: "a4_landscape"
    field :layout_style, :string, default: "classic"
    field :accent_color, :string, default: "deped_blue"
    field :header_title, :string, default: "Department of Education"
    field :header_subtitle, :string, default: "Region IX"
    field :body_intro, :string, default: "This certifies that"

    field :completion_statement, :string,
      default: "successfully completed the authorized learning and development activity"

    field :signature_label, :string, default: "Authorized Issuing Officer"
    field :issuing_office_label, :string, default: "DepEd Region IX"
    field :asset_path, :string
    field :asset_name, :string
    field :asset_content_type, :string
    field :asset_data, :binary
    field :asset_size, :integer
    field :document_reference_code, :string, default: "RO-ORD-F018"
    field :revision_number, :string, default: "00"
    field :effectivity_date, :date, default: ~D[2025-02-20]
    field :participant_name_position, :float, default: 39.0
    field :participant_name_position_source, :string, default: "fallback"

    timestamps(type: :utc_datetime)
  end

  def defaults, do: @defaults
  def editable_fields, do: @editable_fields
  def asset_fields, do: @asset_fields
  def certificate_size_options, do: @certificate_size_options
  def layout_style_options, do: @layout_style_options
  def accent_color_options, do: @accent_color_options

  def changeset(layout_setting, attrs \\ %{}) do
    layout_setting
    |> cast(attrs, [:scope_key | @editable_fields ++ @asset_fields])
    |> normalize_fields()
    |> validate_required([:scope_key])
    |> validate_length(:scope_key, max: 50)
    |> apply_shared_validations()
    |> unique_constraint(:scope_key)
  end

  def override_changeset(changeset) do
    changeset
    |> normalize_fields()
    |> apply_shared_validations()
  end

  defp apply_shared_validations(changeset) do
    changeset
    |> validate_inclusion_if_present(
      resolve_field(changeset, :certificate_size),
      option_values(@certificate_size_options)
    )
    |> validate_inclusion_if_present(
      resolve_field(changeset, :layout_style),
      option_values(@layout_style_options)
    )
    |> validate_inclusion_if_present(
      resolve_field(changeset, :accent_color),
      option_values(@accent_color_options)
    )
    |> validate_length_if_present(resolve_field(changeset, :header_title), 120)
    |> validate_length_if_present(resolve_field(changeset, :header_subtitle), 120)
    |> validate_length_if_present(resolve_field(changeset, :body_intro), 240)
    |> validate_length_if_present(resolve_field(changeset, :completion_statement), 500)
    |> validate_length_if_present(resolve_field(changeset, :signature_label), 120)
    |> validate_length_if_present(resolve_field(changeset, :issuing_office_label), 160)
    |> validate_length_if_present(resolve_field(changeset, :document_reference_code), 80)
    |> validate_length_if_present(resolve_field(changeset, :revision_number), 20)
    |> validate_length_if_present(asset_field(changeset, :asset_path), 500)
    |> validate_length_if_present(asset_field(changeset, :asset_name), 255)
    |> validate_length_if_present(asset_field(changeset, :asset_content_type), 120)
    |> validate_number_if_present(:asset_size, greater_than: 0, less_than_or_equal_to: 8_000_000)
    |> validate_number_if_present(:participant_name_position,
      greater_than_or_equal_to: 15,
      less_than_or_equal_to: 75
    )
    |> validate_inclusion_if_field_present(:participant_name_position_source, [
      "fallback",
      "detected",
      "manual"
    ])
  end

  defp normalize_fields(changeset) do
    fields =
      @editable_fields
      |> Enum.map(&resolve_field(changeset, &1))
      |> Enum.reject(&is_nil/1)
      |> Kernel.++(@asset_fields |> Enum.filter(&Map.has_key?(changeset.types, &1)))
      |> Kernel.++(if(Map.has_key?(changeset.types, :scope_key), do: [:scope_key], else: []))

    Enum.reduce(fields, changeset, fn field, acc ->
      update_change(acc, field, &normalize_text/1)
    end)
  end

  defp validate_inclusion_if_present(changeset, nil, _values), do: changeset

  defp validate_inclusion_if_present(changeset, field, values) do
    case get_change(changeset, field) do
      nil -> changeset
      _value -> validate_inclusion(changeset, field, values, message: "is not supported")
    end
  end

  defp validate_length_if_present(changeset, nil, _max), do: changeset

  defp validate_length_if_present(changeset, field, max) do
    validate_length(changeset, field, max: max)
  end

  defp validate_number_if_present(changeset, field, options) do
    if Map.has_key?(changeset.types, field),
      do: validate_number(changeset, field, options),
      else: changeset
  end

  defp validate_inclusion_if_field_present(changeset, field, values) do
    if Map.has_key?(changeset.types, field),
      do: validate_inclusion(changeset, field, values),
      else: changeset
  end

  defp normalize_text(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value), do: value

  defp option_values(options), do: Enum.map(options, &elem(&1, 1))

  defp resolve_field(changeset, logical_field) do
    @field_aliases
    |> Map.fetch!(logical_field)
    |> Enum.find(&Map.has_key?(changeset.types, &1))
  end

  defp asset_field(changeset, field) do
    if Map.has_key?(changeset.types, field), do: field
  end
end
