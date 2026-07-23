defmodule Tracms.OrganizationFixtures do
  @moduledoc """
  Test helpers for organization and access foundation records.
  """

  alias Tracms.Accounts.Role
  alias Tracms.Organization
  alias Tracms.Repo

  def unique_division_code, do: "DIV#{System.unique_integer([:positive])}"
  def unique_office_code, do: "OFF#{System.unique_integer([:positive])}"
  def unique_role_key, do: "role_#{System.unique_integer([:positive])}"

  def division_fixture(attrs \\ %{}) do
    {:ok, division} =
      attrs
      |> Enum.into(%{
        code: unique_division_code(),
        name: "Division #{System.unique_integer([:positive])}",
        region: "Region IX"
      })
      |> Organization.create_division()

    division
  end

  def office_fixture(attrs \\ %{}) do
    division = Map.get_lazy(attrs, :division, fn -> division_fixture() end)

    attrs =
      attrs
      |> Map.delete(:division)
      |> Enum.into(%{
        code: unique_office_code(),
        name: "Office #{System.unique_integer([:positive])}",
        level: :division,
        division_id: division.id
      })

    {:ok, office} = Organization.create_office(attrs)
    office
  end

  def role_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        key: unique_role_key(),
        name: "Role #{System.unique_integer([:positive])}",
        scope: :office
      })

    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert!()
  end
end
