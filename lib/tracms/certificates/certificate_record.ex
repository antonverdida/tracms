defmodule Tracms.Certificates.CertificateRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Registrations.Registration

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @delivery_status_values [:available, :emailed, :downloaded]

  schema "certificate_records" do
    field :certificate_number, :string
    field :certificate_type, :string
    field :issued_on, :date
    field :delivery_status, Ecto.Enum, values: @delivery_status_values, default: :available
    field :emailed_at, :utc_datetime
    field :downloaded_at, :utc_datetime

    belongs_to :registration, Registration
    belongs_to :issued_by_user, User

    timestamps(type: :utc_datetime)
  end

  def delivery_status_values, do: @delivery_status_values

  def changeset(certificate_record, attrs) do
    certificate_record
    |> cast(attrs, [
      :certificate_number,
      :certificate_type,
      :issued_on,
      :delivery_status,
      :emailed_at,
      :downloaded_at,
      :registration_id,
      :issued_by_user_id
    ])
    |> validate_required([
      :certificate_number,
      :certificate_type,
      :issued_on,
      :delivery_status,
      :registration_id,
      :issued_by_user_id
    ])
    |> validate_length(:certificate_number, max: 120)
    |> validate_length(:certificate_type, max: 160)
    |> unique_constraint(:certificate_number)
    |> unique_constraint(:registration_id)
    |> assoc_constraint(:registration)
    |> assoc_constraint(:issued_by_user)
  end
end
