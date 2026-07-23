defmodule Tracms.Organization.Division do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "divisions" do
    field :code, :string
    field :name, :string
    field :region, :string, default: "Region IX"
    field :is_active, :boolean, default: true

    has_many :offices, Tracms.Organization.Office

    timestamps(type: :utc_datetime)
  end

  def changeset(division, attrs) do
    division
    |> cast(attrs, [:code, :name, :region, :is_active])
    |> validate_required([:code, :name, :region])
    |> validate_length(:code, max: 32)
    |> validate_length(:name, max: 160)
    |> validate_length(:region, max: 80)
    |> unique_constraint(:code)
    |> unique_constraint(:name)
  end
end
