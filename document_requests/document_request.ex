defmodule Tracms.DocumentRequests.DocumentRequest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @document_types ["Certificate", "Service Record", "Appointment Paper", "Leave Record", "Other Document"]
  @statuses [:pending, :under_review, :approved, :released, :rejected, :archived]

  schema "document_requests" do
    field :request_number, :string
    field :document_type, :string
    field :purpose, :string
    field :requested_on, :date
    field :status, Ecto.Enum, values: @statuses, default: :pending
    belongs_to :requester, Tracms.Accounts.User
    belongs_to :approved_by, Tracms.Accounts.User
    has_one :document_control, Tracms.DocumentRequests.DocumentControl
    timestamps(type: :utc_datetime)
  end

  def document_types, do: @document_types

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:document_type, :purpose, :requested_on])
    |> validate_required([:document_type, :purpose, :requested_on])
    |> validate_inclusion(:document_type, @document_types)
    |> validate_length(:purpose, min: 5, max: 1_000)
  end
end
