defmodule TracmsWeb.TrainingLive.ReportsTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.TrainingsFixtures

  test "renders operational reports for a training manager", %{conn: conn} do
    %{scope: scope, user: user} = training_manager_scope_fixture()
    training = training_activity_fixture(scope, %{title: "Regional Accomplishment Report"})

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/reports")

    assert has_element?(view, "#reports-training-table")
    assert has_element?(view, ".ui-data-table")
    assert has_element?(view, "#report-training-#{training.id}")
    assert has_element?(view, "#reports-registration-summary.ui-card")
    assert has_element?(view, "#reports-attendance-summary")
    assert has_element?(view, "#reports-completion-summary")
  end
end
