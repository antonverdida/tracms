defmodule Tracms.Evaluations.EvaluationSubmission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Registrations.Registration

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "evaluation_submissions" do
    field :overall_rating, :integer
    field :feedback, :string
    field :application_plan, :string
    field :submitted_at, :utc_datetime

    belongs_to :registration, Registration
    belongs_to :submitted_by_user, User

    timestamps(type: :utc_datetime)
  end

  def rating_options do
    [
      {"5 - Excellent", 5},
      {"4 - Very good", 4},
      {"3 - Good", 3},
      {"2 - Fair", 2},
      {"1 - Needs improvement", 1}
    ]
  end

  def changeset(evaluation_submission, attrs) do
    evaluation_submission
    |> cast(attrs, [
      :overall_rating,
      :feedback,
      :application_plan,
      :submitted_at,
      :registration_id,
      :submitted_by_user_id
    ])
    |> validate_required([:overall_rating, :submitted_at, :registration_id, :submitted_by_user_id])
    |> validate_number(:overall_rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> validate_length(:feedback, max: 2_000)
    |> validate_length(:application_plan, max: 2_000)
    |> unique_constraint(:registration_id)
    |> assoc_constraint(:registration)
    |> assoc_constraint(:submitted_by_user)
  end
end
