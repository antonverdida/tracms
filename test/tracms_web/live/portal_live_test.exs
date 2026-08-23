defmodule TracmsWeb.PortalLiveTest do
  use TracmsWeb.ConnCase, async: true

  describe "dashboard navigation" do
    test "manager sees the full top menu", %{conn: conn} do
      %{user: user} = Tracms.TrainingsFixtures.training_manager_scope_fixture()

      html =
        conn
        |> log_in_user(user)
        |> get(~p"/dashboard")
        |> html_response(200)

      assert html =~ "Dashboard"
      assert html =~ "Training Management"
      assert html =~ "Registrations"
      assert html =~ "Attendance"
      assert html =~ "Certificates"
      assert html =~ "Settings"
      assert html =~ "Total Trainings"
      assert html =~ "Total Registrations"
      assert html =~ "Total Attendees"
      assert html =~ "Certificates Generated"
      assert html =~ "Upcoming Trainings"
      assert html =~ "Recent Registrations"
      assert html =~ "Recent Certificates Generated"
      assert html =~ "View certificates"
      assert html =~ "Add Training"
      assert html =~ "View Registrations"
      assert html =~ "Record Attendance"
      assert html =~ "Generate Certificates"
    end

    test "non-manager users are redirected away from the admin dashboard", %{conn: conn} do
      user = Tracms.AccountsFixtures.user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/dashboard")

      assert redirected_to(conn) == ~p"/"
    end
  end
end
