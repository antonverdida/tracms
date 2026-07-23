defmodule Tracms.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @scope_values [:system, :region, :division, :office, :participant]

  schema "roles" do
    field :key, :string
    field :name, :string
    field :description, :string
    field :scope, Ecto.Enum, values: @scope_values
    field :is_assignable, :boolean, default: true

    has_many :users, Tracms.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(role, attrs) do
    role
    |> cast(attrs, [:key, :name, :description, :scope, :is_assignable])
    |> validate_required([:key, :name, :scope])
    |> validate_length(:key, max: 64)
    |> validate_format(:key, ~r/^[a-z0-9_]+$/,
      message: "must contain only lowercase letters, numbers, and underscores"
    )
    |> validate_length(:name, max: 160)
    |> unique_constraint(:key)
  end
end
