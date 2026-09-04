defmodule TracmsWeb.DashboardGreeting do
  @moduledoc false

  @philippine_offset_hours 8

  def for_utc_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.add(@philippine_offset_hours, :hour)
    |> greeting_for_hour()
  end

  defp greeting_for_hour(%DateTime{hour: hour}) when hour < 12, do: "Good Morning"
  defp greeting_for_hour(%DateTime{hour: hour}) when hour < 18, do: "Good Afternoon"
  defp greeting_for_hour(_datetime), do: "Good Evening"
end
