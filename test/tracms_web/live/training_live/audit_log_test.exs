defmodule TracmsWeb.TrainingLive.AuditLogTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.TrainingsFixtures

  test "renders scoped audit events for a training manager", %{conn: conn} do
    %{scope: scope, user: user} = manager = training_manager_scope_fixture()
    training = published_training_fixture_for_manager(scope)
    participant = Tracms.RegistrationsFixtures.participant_scope_fixture()

    _registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/audit-logs")

    assert has_element?(view, "#audit-log-filter-form")
    assert has_element?(view, "#audit-log-table-table.ui-data-table")
    assert has_element?(view, "#audit-log-table", "Registration Reviewed")
  end
end
