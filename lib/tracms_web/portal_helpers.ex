defmodule TracmsWeb.PortalHelpers do
  @moduledoc """
  Shared formatting helpers for portal-oriented views.
  """

  def summary_card(label, value, meta), do: %{label: label, value: value, meta: meta}

  def training_workspace_nav_items(training_id, active_section) do
    [
      %{
        key: :registrations,
        label: "Registrations",
        path: "/registrations?training_id=#{training_id}&view=manage"
      },
      %{key: :attendance, label: "Attendance", path: "/attendance?training_id=#{training_id}"},
      %{key: :completion, label: "Completion", path: "/trainings/#{training_id}/completion"},
      %{
        key: :certificates,
        label: "Certificates",
        path: "/certificates/trainings/#{training_id}"
      },
      %{key: :integrations, label: "Integrations", path: "/trainings/#{training_id}/integrations"}
    ]
    |> Enum.map(fn item -> Map.put(item, :active?, item.key == active_section) end)
  end

  def format_date(nil), do: "Schedule to be announced"

  def format_date(%Date{} = date) do
    "#{Calendar.strftime(date, "%b")} #{date.day}, #{date.year}"
  end

  def format_datetime(nil), do: "Schedule to be announced"

  def format_datetime(%DateTime{} = datetime) do
    "#{format_date(DateTime.to_date(datetime))} • #{Calendar.strftime(datetime, "%I:%M %p")}"
  end

  def format_datetime(%NaiveDateTime{} = datetime) do
    "#{format_date(NaiveDateTime.to_date(datetime))} • #{Calendar.strftime(datetime, "%I:%M %p")}"
  end

  def format_time(nil), do: "Time to be announced"

  def format_time(%Time{} = time) do
    Calendar.strftime(time, "%I:%M %p")
  end

  def format_modality(modality) when is_atom(modality) do
    modality
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
