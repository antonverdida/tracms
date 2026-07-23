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

  schema "training_activities" do
    field :title, :string
    field :description, :string
    field :category, :string
    field :organizer, :string
    field :modality, Ecto.Enum, values: @modality_values
    field :venue, :string
    field :status, Ecto.Enum, values: @status_values, default: :draft
    field :registration_deadline, :utc_datetime
    field :max_capacity, :integer
    field :starts_on, :date
    field :ends_on, :date
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
      :organizer,
      :modality,
      :venue,
      :status,
      :registration_deadline,
      :max_capacity,
      :starts_on,
      :ends_on,
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
      :organizer,
      :modality,
      :venue,
      :status,
      :registration_deadline,
      :max_capacity,
      :starts_on,
      :ends_on,
      :minimum_attendance_percentage,
      :evaluation_required
    ])
    |> validate_length(:title, max: 200)
    |> validate_length(:description, max: 5_000)
    |> validate_length(:category, max: 120)
    |> validate_length(:organizer, max: 200)
    |> validate_length(:venue, max: 200)
    |> validate_number(:max_capacity, greater_than: 0, less_than_or_equal_to: 100_000)
    |> validate_number(:minimum_attendance_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> validate_registration_deadline()
    |> validate_schedule_range()
    |> assoc_constraint(:creator_user)
    |> assoc_constraint(:office)
    |> assoc_constraint(:division)
  end

  defp validate_registration_deadline(changeset) do
    deadline = get_field(changeset, :registration_deadline)
    starts_on = get_field(changeset, :starts_on)

    cond do
      is_nil(deadline) or is_nil(starts_on) ->
        changeset

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
