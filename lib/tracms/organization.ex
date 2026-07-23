defmodule Tracms.Organization do
  @moduledoc """
  The Organization context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Organization.{Division, Office}
  alias Tracms.Repo

  def list_divisions do
    Division
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_division!(id), do: Repo.get!(Division, id)

  def get_division_by_code(code) when is_binary(code) do
    Repo.get_by(Division, code: code)
  end

  def create_division(attrs \\ %{}) do
    %Division{}
    |> Division.changeset(attrs)
    |> Repo.insert()
  end

  def change_division(%Division{} = division, attrs \\ %{}) do
    Division.changeset(division, attrs)
  end

  def list_offices do
    Office
    |> preload(:division)
    |> order_by([office], asc: office.level, asc: office.name)
    |> Repo.all()
  end

  def list_division_offices(division_id) when is_binary(division_id) do
    Office
    |> where([office], office.division_id == ^division_id)
    |> preload(:division)
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_office!(id) do
    Office
    |> Repo.get!(id)
    |> Repo.preload(:division)
  end

  def get_office_by_code(code) when is_binary(code) do
    Office
    |> Repo.get_by(code: code)
    |> maybe_preload_office()
  end

  def create_office(attrs \\ %{}) do
    %Office{}
    |> Office.changeset(attrs)
    |> Repo.insert()
    |> preload_office_result()
  end

  def change_office(%Office{} = office, attrs \\ %{}) do
    Office.changeset(office, attrs)
  end

  defp preload_office_result({:ok, office}), do: {:ok, Repo.preload(office, :division)}
  defp preload_office_result(other), do: other

  defp maybe_preload_office(nil), do: nil
  defp maybe_preload_office(office), do: Repo.preload(office, :division)
end
