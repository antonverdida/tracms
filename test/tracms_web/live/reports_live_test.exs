defmodule TracmsWeb.ReportsLiveTest do
  use TracmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Evaluations

  describe "reports page" do
    test "renders training operations reports for a manager", %{conn: conn} do
      %{scope: scope, user: user} = training_manager_scope_fixture()

      training_activity =
        training_activity_fixture(scope, %{
          title: "Leadership Development Program",
          status: :published,
          evaluation_required: true
        })

      approved_registration =
        approved_registration_fixture(
          training_manager: %{scope: scope},
          training_activity: training_activity,
          participant: Tracms.RegistrationsFixtures.participant_scope_fixture()
        )

      _submitted_registration =
        registration_fixture(%{
          training_activity: training_activity
        })

      session =
        attendance_session_fixture(
          training_manager: %{scope: scope},
          training_activity: training_activity,
          name: "Day 1 AM"
        )

      assert {:ok, session} = Attendance.open_session(scope, session)

      assert {:ok, _record} =
               Attendance.mark_attendance(scope, session.id, approved_registration.id, %{
                 status: :present
               })

      participant_scope = Tracms.Accounts.Scope.for_user(approved_registration.registrant_user)

      assert {:ok, _submission} =
               Evaluations.submit_evaluation(participant_scope, approved_registration.id, %{
                 overall_rating: 5,
                 feedback: "Very helpful training",
                 application_plan: "Use the strategies in school planning."
               })

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/reports")

      assert html =~ "Training Operations Reports"
      assert html =~ "Leadership Development Program"
      assert html =~ "Registration Status"
      assert html =~ "Attendance Session Summary"
      assert html =~ "Completion Summary"
    end
  end
end
