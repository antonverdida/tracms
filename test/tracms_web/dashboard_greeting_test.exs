defmodule TracmsWeb.DashboardGreetingTest do
  use ExUnit.Case, async: true

  alias TracmsWeb.DashboardGreeting

  test "uses Philippine time to choose the dashboard greeting" do
    assert DashboardGreeting.for_utc_datetime(~U[2026-01-01 03:59:00Z]) == "Good Morning"
    assert DashboardGreeting.for_utc_datetime(~U[2026-01-01 04:00:00Z]) == "Good Afternoon"
    assert DashboardGreeting.for_utc_datetime(~U[2026-01-01 10:00:00Z]) == "Good Evening"
  end
end
