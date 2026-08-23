defmodule Tracms.Registrations.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:submitted, :approved, :rejected, :waitlisted, :withdrawn]

  schema "registrations" do
    field :status, Ecto.Enum, values: @status_values, default: :submitted
    field :special_requirements, :string
    field :review_notes, :string
    field :manual_participant_name, :string
    field :manual_participant_email, :string
    field :submitted_at, :utc_datetime
    field :reviewed_at, :utc_datetime

    belongs_to :training_activity, TrainingActivity
    belongs_to :registrant_user, User
    belongs_to :reviewer_user, User
    has_one :certificate_record, CertificateRecord

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [
      :status,
      :special_requirements,
      :review_notes,
      :submitted_at,
      :reviewed_at,
      :manual_participant_name,
      :manual_participant_email,
      :training_activity_id,
      :registrant_user_id,
      :reviewer_user_id
    ])
    |> validate_required([:status, :submitted_at, :training_activity_id])
    |> validate_participant()
    |> validate_length(:special_requirements, max: 1_000)
    |> validate_length(:review_notes, max: 1_000)
    |> validate_length(:manual_participant_name, max: 160)
    |> validate_length(:manual_participant_email, max: 160)
    |> validate_format(:manual_participant_email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> unique_constraint([:training_activity_id, :registrant_user_id])
    |> assoc_constraint(:training_activity)
    |> assoc_constraint(:registrant_user)
    |> assoc_constraint(:reviewer_user)
  end

  defp validate_participant(changeset) do
    case {get_field(changeset, :registrant_user_id),
          get_field(changeset, :manual_participant_name)} do
      {user_id, _name} when is_binary(user_id) ->
        changeset

      {nil, name} when is_binary(name) ->
        if String.trim(name) == "" do
          add_error(
            changeset,
            :manual_participant_name,
            "must be provided for a guest participant"
          )
        else
          changeset
        end

      _ ->
        add_error(changeset, :manual_participant_name, "must be provided for a guest participant")
    end
  end
end
