defmodule Tracms.Trainings.TrainingActivity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Organization.{Division, Office}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [
    :draft,
    :pending_division_approval,
    :pending_region_approval,
    :published,
    :registration_closed,
    :in_progress,
    :completed,
    :archived
  ]

  @modality_values [:face_to_face, :online, :hybrid]
  @category_options [
    "Teacher Development",
    "School Leadership",
    "Curriculum and Instruction",
    "Information and Communication Technology",
    "Assessment and Evaluation",
    "Inclusive Education",
    "Governance and Administration"
  ]
  @training_type_options [
    "Capacity Building Training",
    "Professional Development Program",
    "Leadership Development Program",
    "Technical Assistance",
    "Orientation and Workshop",
    "Assessment and Evaluation Activity"
  ]
  @certificate_type_options [
    "Certificate of Participation",
    "Certificate of Completion",
    "Certificate of Recognition"
  ]
  @attendance_monitoring_method_options [
    "QR Code Attendance",
    "Manual Verification",
    "QR Code and Manual Verification"
  ]

  schema "training_activities" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :training_type, :string
    field :organizer, :string
    field :modality, Ecto.Enum, values: @modality_values
    field :venue, :string
    field :venue_address, :string
    field :status, Ecto.Enum, values: @status_values, default: :draft
    field :registration_opens_on, :date
    field :registration_deadline, :utc_datetime
    field :max_capacity, :integer
    field :starts_on, :date
    field :ends_on, :date
    field :total_hours, :integer
    field :objectives, :string
    field :target_participants, :string
    field :participant_qualification, :string
    field :attendance_monitoring_method, :string
    field :certificate_type, :string
    field :published_at, :utc_datetime
    field :minimum_attendance_percentage, :integer, default: 75
    field :evaluation_required, :boolean, default: false

    belongs_to :creator_user, User
    belongs_to :office, Office
    belongs_to :division, Division

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values
  def modality_values, do: @modality_values
  def category_options, do: Enum.map(@category_options, &{&1, &1})
  def training_type_options, do: Enum.map(@training_type_options, &{&1, &1})
  def certificate_type_options, do: Enum.map(@certificate_type_options, &{&1, &1})

  def attendance_monitoring_method_options do
    Enum.map(@attendance_monitoring_method_options, &{&1, &1})
  end

  def modality_options do
    [
      {"Face-to-face", "face_to_face"},
      {"Online", "online"},
      {"Hybrid", "hybrid"}
    ]
  end

  def changeset(training_activity, attrs) do
    training_activity
    |> cast(attrs, [
      :title,
      :description,
      :category,
      :training_type,
      :organizer,
      :modality,
      :venue,
      :venue_address,
      :status,
      :registration_opens_on,
      :registration_deadline,
      :max_capacity,
      :starts_on,
      :ends_on,
      :total_hours,
      :objectives,
      :target_participants,
      :participant_qualification,
      :attendance_monitoring_method,
      :certificate_type,
      :published_at,
      :minimum_attendance_percentage,
      :evaluation_required,
      :creator_user_id,
      :office_id,
      :division_id
    ])
    |> validate_required([
      :title,
      :description,
      :category,
      :training_type,
      :organizer,
      :modality,
      :venue,
      :venue_address,
      :status,
      :registration_opens_on,
      :registration_deadline,
      :max_capacity,
      :starts_on,
      :ends_on,
      :total_hours,
      :objectives,
      :target_participants,
      :participant_qualification,
      :attendance_monitoring_method,
      :certificate_type,
      :minimum_attendance_percentage,
      :evaluation_required
    ])
    |> validate_length(:title, max: 200)
    |> validate_length(:description, max: 5_000)
    |> validate_length(:objectives, max: 5_000)
    |> validate_length(:category, max: 120)
    |> validate_length(:training_type, max: 120)
    |> validate_length(:organizer, max: 200)
    |> validate_length(:venue, max: 200)
    |> validate_length(:venue_address, max: 255)
    |> validate_length(:target_participants, max: 2_000)
    |> validate_length(:participant_qualification, max: 3_000)
    |> validate_length(:attendance_monitoring_method, max: 120)
    |> validate_length(:certificate_type, max: 120)
    |> validate_number(:max_capacity, greater_than: 0, less_than_or_equal_to: 100_000)
    |> validate_number(:total_hours, greater_than: 0, less_than_or_equal_to: 1_000)
    |> validate_number(:minimum_attendance_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_inclusion(:category, @category_options)
    |> validate_inclusion(:training_type, @training_type_options)
    |> validate_inclusion(:certificate_type, @certificate_type_options)
    |> validate_inclusion(:attendance_monitoring_method, @attendance_monitoring_method_options)
    |> validate_registration_opening()
    |> validate_registration_deadline()
    |> validate_schedule_range()
    |> assoc_constraint(:creator_user)
    |> assoc_constraint(:office)
    |> assoc_constraint(:division)
  end

  defp validate_registration_deadline(changeset) do
    opens_on = get_field(changeset, :registration_opens_on)
    deadline = get_field(changeset, :registration_deadline)
    starts_on = get_field(changeset, :starts_on)

    cond do
      is_nil(deadline) or is_nil(starts_on) ->
        changeset

      not is_nil(opens_on) and Date.compare(DateTime.to_date(deadline), opens_on) == :lt ->
        add_error(
          changeset,
          :registration_deadline,
          "must be on or after the registration opening date"
        )

      Date.compare(DateTime.to_date(deadline), starts_on) == :gt ->
        add_error(
          changeset,
          :registration_deadline,
          "must be on or before the training start date"
        )

      true ->
        changeset
    end
  end

  defp validate_registration_opening(changeset) do
    opens_on = get_field(changeset, :registration_opens_on)
    starts_on = get_field(changeset, :starts_on)

    cond do
      is_nil(opens_on) or is_nil(starts_on) ->
        changeset

      Date.compare(opens_on, starts_on) == :gt ->
        add_error(
          changeset,
          :registration_opens_on,
          "must be on or before the training start date"
        )

      true ->
        changeset
    end
  end

  defp validate_schedule_range(changeset) do
    starts_on = get_field(changeset, :starts_on)
    ends_on = get_field(changeset, :ends_on)

    cond do
      is_nil(starts_on) or is_nil(ends_on) ->
        changeset

      Date.compare(ends_on, starts_on) == :lt ->
        add_error(changeset, :ends_on, "must be on or after the training start date")

      true ->
        changeset
    end
  end
end
