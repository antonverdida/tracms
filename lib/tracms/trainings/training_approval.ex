defmodule Tracms.Trainings.TrainingApproval do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @action_values [
    :created,
    :submitted_to_division,
    :submitted_to_region,
    :advanced_to_region_approval,
    :published,
    :returned_for_revision
  ]

  schema "training_approvals" do
    field :action, Ecto.Enum, values: @action_values
    field :actor_role_key, :string
    field :from_status, Ecto.Enum, values: TrainingActivity.status_values()
    field :to_status, Ecto.Enum, values: TrainingActivity.status_values()
    field :notes, :string

    belongs_to :training_activity, TrainingActivity
    belongs_to :acted_by_user, User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def action_values, do: @action_values

  def changeset(training_approval, attrs) do
    training_approval
    |> cast(attrs, [
      :action,
      :actor_role_key,
      :from_status,
      :to_status,
      :notes,
      :training_activity_id,
      :acted_by_user_id
    ])
    |> validate_required([
      :action,
      :actor_role_key,
      :to_status,
      :training_activity_id
    ])
    |> validate_length(:actor_role_key, max: 64)
    |> validate_length(:notes, max: 2_000)
    |> assoc_constraint(:training_activity)
    |> assoc_constraint(:acted_by_user)
  end
end
