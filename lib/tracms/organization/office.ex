defmodule Tracms.Organization.Office do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @level_values [:regional, :division, :school, :unit]

  schema "offices" do
    field :code, :string
    field :name, :string
    field :level, Ecto.Enum, values: @level_values
    field :email, :string
    field :phone, :string
    field :is_active, :boolean, default: true

    belongs_to :division, Tracms.Organization.Division
    has_many :users, Tracms.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(office, attrs) do
    office
    |> cast(attrs, [:code, :name, :level, :email, :phone, :is_active, :division_id])
    |> validate_required([:code, :name, :level])
    |> validate_length(:code, max: 32)
    |> validate_length(:name, max: 160)
    |> validate_length(:email, max: 160)
    |> validate_length(:phone, max: 40)
    |> assoc_constraint(:division)
    |> unique_constraint(:code)
  end
end
