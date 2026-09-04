defmodule Tracms.Notifications.Delivery do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Registrations.Registration
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_deliveries" do
    field :type, :string
    field :status, Ecto.Enum, values: [:queued, :delivered, :skipped, :failed], default: :queued
    field :payload, :map, default: %{}
    field :delivered_at, :utc_datetime
    field :failed_at, :utc_datetime
    belongs_to :recipient_user, User
    belongs_to :registration, Registration
    belongs_to :training_activity, TrainingActivity
    timestamps(type: :utc_datetime)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :type,
      :status,
      :payload,
      :delivered_at,
      :failed_at,
      :recipient_user_id,
      :registration_id,
      :training_activity_id
    ])
    |> validate_required([
      :type,
      :status,
      :recipient_user_id,
      :registration_id,
      :training_activity_id
    ])
    |> validate_length(:type, max: 100)
    |> unique_constraint(:registration_id,
      name: :notification_deliveries_type_registration_id_index,
      message: "already queued for this registration and notification type"
    )
  end
end
