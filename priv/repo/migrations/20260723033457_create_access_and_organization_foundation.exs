defmodule Tracms.Repo.Migrations.CreateAccessAndOrganizationFoundation do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :scope, :string, null: false
      add :is_assignable, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:key])

    create table(:divisions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :region, :string, null: false, default: "Region IX"
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:divisions, [:code])
    create unique_index(:divisions, [:name])

    create table(:offices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :level, :string, null: false
      add :email, :string
      add :phone, :string
      add :is_active, :boolean, null: false, default: true
      add :division_id, references(:divisions, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:offices, [:code])
    create index(:offices, [:division_id])
    create index(:offices, [:level])

    alter table(:users) do
      add :full_name, :string
      add :employee_number, :string
      add :status, :string, null: false, default: "pending"
      add :approved_at, :utc_datetime
      add :role_id, references(:roles, type: :binary_id, on_delete: :nilify_all)
      add :office_id, references(:offices, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:users, [:status])
    create index(:users, [:role_id])
    create index(:users, [:office_id])
  end
end
