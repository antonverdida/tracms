defmodule Tracms.DocumentRequests.DocumentControl do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "document_controls" do
    field :document_code, :string
    field :document_title, :string
    field :revision_number, :string, default: "00"
    field :effectivity_date, :date
    field :status, Ecto.Enum, values: [:draft, :active, :superseded, :archived], default: :active
    belongs_to :document_request, Tracms.DocumentRequests.DocumentRequest
    belongs_to :created_by, Tracms.Accounts.User
    belongs_to :approved_by, Tracms.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(control, attrs) do
    control
    |> cast(attrs, [:document_code, :document_title, :revision_number, :effectivity_date])
    |> validate_required([:document_code, :document_title, :revision_number, :effectivity_date])
    |> validate_length(:document_code, max: 80)
    |> validate_length(:document_title, max: 180)
    |> validate_length(:revision_number, max: 20)
    |> unique_constraint(:document_code)
  end
end
