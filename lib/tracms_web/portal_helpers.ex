defmodule TracmsWeb.PortalHelpers do
  @moduledoc """
  Shared formatting helpers for portal-oriented views.
  """

  def summary_card(label, value, meta), do: %{label: label, value: value, meta: meta}

  def format_date(nil), do: "Schedule to be announced"

  def format_date(%Date{} = date) do
    "#{Calendar.strftime(date, "%b")} #{date.day}, #{date.year}"
  end

  def format_datetime(nil), do: "Schedule to be announced"

  def format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_date()
    |> format_date()
  end

  def format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.to_date()
    |> format_date()
  end

  def format_modality(modality) when is_atom(modality) do
    modality
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
