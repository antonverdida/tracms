defmodule Tracms.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :string
    field :metadata, :map, default: %{}

    belongs_to :actor_user, User
    belongs_to :training_activity, TrainingActivity

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :action,
      :entity_type,
      :entity_id,
      :metadata,
      :actor_user_id,
      :training_activity_id
    ])
    |> validate_required([:action, :entity_type, :entity_id, :actor_user_id])
    |> validate_length(:action, max: 100)
    |> validate_length(:entity_type, max: 80)
    |> validate_length(:entity_id, max: 160)
    |> assoc_constraint(:actor_user)
    |> assoc_constraint(:training_activity)
  end
end
