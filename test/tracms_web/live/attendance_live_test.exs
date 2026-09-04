defmodule TracmsWeb.AttendanceLiveTest do
  use TracmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.TrainingsFixtures

  describe "attendance management flow" do
    test "opens the attendance workspace from the training directory", %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")
      training_activity = published_training_fixture_for_manager(manager.scope)

      conn = log_in_user(conn, manager.user)

      {:ok, lv, html} = live(conn, ~p"/attendance")

      assert html =~ "List of Attendance"
      assert html =~ "Choose a Training First"
      assert has_element?(lv, "#attendance-training-directory-table.ui-data-table")

      assert has_element?(lv, "a[href='/attendance?training_id=#{training_activity.id}']", "View")

      {:ok, list_lv, _html} = live(conn, ~p"/attendance?training_id=#{training_activity.id}")

      refute has_element?(list_lv, "#attendance-session-form")
      assert has_element?(list_lv, "#attendance-filters")
      assert has_element?(list_lv, "#attendance-roster-table.ui-data-table")
      assert has_element?(list_lv, ".portal-empty-state", "No Participants Found")
      assert has_element?(list_lv, ".portal-mini-stat-card", "Total Participants")
      assert has_element?(list_lv, ".portal-mini-stat-card", "Attendance Recorded")
      assert has_element?(list_lv, ".portal-mini-stat-card", "Not Recorded")

      assert has_element?(
               list_lv,
               "a[href*='/registrations?'][href*='view=manage'][href*='manual=true']"
             )

      assert has_element?(list_lv, "a[href*='/attendance/export/excel']")
      assert has_element?(list_lv, "a[href*='/attendance/export/pdf']")

      assert has_element?(lv, "a[href*='view=workspace']", "Attendance Workspace")

      {:ok, workspace_lv, _html} =
        live(conn, ~p"/attendance?training_id=#{training_activity.id}&view=workspace")

      assert has_element?(workspace_lv, "#attendance-session-form")
    end

    test "creates and opens attendance sessions from the central attendance page", %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")
      training_activity = published_training_fixture_for_manager(manager.scope)

      {:ok, lv, _html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/attendance?training_id=#{training_activity.id}&view=workspace")

      assert has_element?(lv, "#attendance-session-form")

      lv
      |> form("#attendance-session-form",
        attendance_session: %{
          "name" => "Day 1 - Morning Session",
          "session_date" => "2026-08-23",
          "starts_at" => "08:00",
          "ends_at" => "12:00"
        }
      )
      |> render_submit()

      assert has_element?(lv, "button[phx-click=\"open_session\"]", "Open Session")

      lv
      |> element("button[phx-click=\"open_session\"]", "Open Session")
      |> render_click()

      assert has_element?(lv, "button[phx-click=\"close_session\"]", "Close Session")
    end
  end
end
