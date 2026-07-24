defmodule Tracms.Registrations.ExternalRegistrationSubmission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Registrations.Registration
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:pending_review, :needs_account, :imported, :rejected]

  schema "external_registration_submissions" do
    field :full_name, :string
    field :email, :string
    field :employee_number, :string
    field :office_name, :string
    field :source_reference, :string
    field :special_requirements, :string
    field :review_notes, :string
    field :status, Ecto.Enum, values: @status_values, default: :pending_review
    field :submitted_at, :utc_datetime
    field :reviewed_at, :utc_datetime

    belongs_to :training_activity, TrainingActivity
    belongs_to :matched_user, User
    belongs_to :imported_registration, Registration
    belongs_to :reviewer_user, User

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  def changeset(submission, attrs) do
    submission
    |> cast(attrs, [
      :full_name,
      :email,
      :employee_number,
      :office_name,
      :source_reference,
      :special_requirements,
      :review_notes,
      :status,
      :submitted_at,
      :reviewed_at,
      :training_activity_id,
      :matched_user_id,
      :imported_registration_id,
      :reviewer_user_id
    ])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:full_name, :email, :status, :submitted_at, :training_activity_id])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:full_name, max: 160)
    |> validate_length(:email, max: 160)
    |> validate_length(:employee_number, max: 64)
    |> validate_length(:office_name, max: 160)
    |> validate_length(:source_reference, max: 255)
    |> validate_length(:special_requirements, max: 1_000)
    |> validate_length(:review_notes, max: 1_000)
    |> assoc_constraint(:training_activity)
    |> assoc_constraint(:matched_user)
    |> assoc_constraint(:imported_registration)
    |> assoc_constraint(:reviewer_user)
  end

  defp normalize_email(email) when is_binary(email),
    do: email |> String.trim() |> String.downcase()

  defp normalize_email(email), do: email
end
