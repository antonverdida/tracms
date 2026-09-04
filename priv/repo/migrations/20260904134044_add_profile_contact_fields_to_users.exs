defmodule Tracms.Repo.Migrations.AddProfileContactFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :position, :string
      add :contact_number, :string
    end
  end
end
