defmodule Tracms.OrganizationTest do
  use Tracms.DataCase

  alias Tracms.Organization
  alias Tracms.Organization.{Division, Office}

  import Tracms.OrganizationFixtures

  describe "divisions" do
    test "create_division/1 creates a division" do
      attrs = %{code: "TEST-DIV", name: "Test Division", region: "Region IX"}

      assert {:ok, %Division{} = division} = Organization.create_division(attrs)
      assert division.code == "TEST-DIV"
      assert division.name == "Test Division"
      assert division.region == "Region IX"
    end

    test "list_divisions/0 returns divisions ordered by name" do
      alpha = division_fixture(%{name: "Alpha Division"})
      zeta = division_fixture(%{name: "Zeta Division"})

      assert Enum.map(Organization.list_divisions(), & &1.id) == [alpha.id, zeta.id]
    end
  end

  describe "offices" do
    test "create_office/1 creates an office and preloads the division" do
      division = division_fixture()

      attrs = %{
        code: "OFF-TEST",
        name: "Test Office",
        level: :division,
        division_id: division.id
      }

      assert {:ok, %Office{} = office} = Organization.create_office(attrs)
      assert office.division.id == division.id
      assert office.level == :division
    end

    test "list_offices/0 preloads division data" do
      office = office_fixture()

      [listed_office] = Organization.list_offices()
      assert listed_office.id == office.id
      assert listed_office.division.id == office.division.id
    end
  end
end
