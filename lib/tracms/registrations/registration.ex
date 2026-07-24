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
      :training_activity_id,
      :registrant_user_id,
      :reviewer_user_id
    ])
    |> validate_required([:status, :submitted_at, :training_activity_id, :registrant_user_id])
    |> validate_length(:special_requirements, max: 1_000)
    |> validate_length(:review_notes, max: 1_000)
    |> unique_constraint([:training_activity_id, :registrant_user_id])
    |> assoc_constraint(:training_activity)
    |> assoc_constraint(:registrant_user)
    |> assoc_constraint(:reviewer_user)
  end
end
