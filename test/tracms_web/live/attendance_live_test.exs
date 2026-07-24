defmodule TracmsWeb.AttendanceLiveTest do
  use TracmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "attendance management flow" do
    test "creates a session, opens it, and marks attendance", %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")

      training_activity =
        published_training_fixture_for_manager(manager.scope, %{
          attendance_sheet_id: "attendance-sheet-main",
          attendance_sheet_range: "Attendance!A:C"
        })

      registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity,
          participant:
            participant_scope_fixture(%{
              email: "attendance.participant@example.com",
              full_name: "Attendance Participant"
            })
        )

      {:ok, lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/attendance")

      assert html =~ "Create attendance session"
      assert html =~ "Attendance method"
      assert html =~ "Recommended session naming"

      html =
        lv
        |> form("#attendance-session-form",
          attendance_session: %{
            name: "Day 1 PM",
            session_date: to_string(training_activity.starts_on),
            starts_at: "13:00",
            ends_at: "17:00"
          }
        )
        |> render_submit()

      assert html =~ "Attendance session created successfully."
      assert html =~ "Day 1 PM"
      assert html =~ registration.registrant_user.full_name

      html =
        lv
        |> element("button[phx-click=\"open_session\"]", "Open session")
        |> render_click()

      assert html =~ "Attendance session is now open."
      assert html =~ "Open"

      html =
        lv
        |> element(
          "button[phx-click=\"mark_attendance\"][phx-value-registration_id=\"#{registration.id}\"][phx-value-status=\"present\"]",
          "Present"
        )
        |> render_click()

      assert html =~ "Attendance updated successfully."
      assert html =~ "Present"
      assert html =~ "Attendance rate"
      assert html =~ "Present today"

      html =
        lv
        |> element("button[phx-click=\"sync_google_sheet_attendance\"]", "Sync Google Sheet")
        |> render_click()

      assert html =~ "Attendance sync completed: 1 updated, 0 skipped, 1 errors."
      assert html =~ "Latest Sync Result"
      assert html =~ "Rows needing review"
      assert html =~ "missing.participant@example.com"
    end
  end
end
