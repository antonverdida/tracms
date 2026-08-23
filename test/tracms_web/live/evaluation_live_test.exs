defmodule TracmsWeb.EvaluationLiveTest do
  use TracmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.EvaluationsFixtures

  alias Tracms.Attendance
  alias Tracms.Evaluations

  describe "manager completion summary" do
    test "shows computed completion results", %{conn: conn} do
      manager = Tracms.TrainingsFixtures.training_manager_scope_fixture("training_coordinator")
      training_activity = evaluable_training_fixture_for_manager(manager.scope)

      completed_registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      pending_registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      session =
        attendance_session_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      {:ok, session} = Attendance.open_session(manager.scope, session)

      assert {:ok, _} =
               Attendance.mark_attendance(manager.scope, session.id, completed_registration.id, %{
                 status: :present
               })

      assert {:ok, _} =
               Attendance.mark_attendance(manager.scope, session.id, pending_registration.id, %{
                 status: :present
               })

      participant_scope = Tracms.Accounts.Scope.for_user(completed_registration.registrant_user)

      assert {:ok, _submission} =
               Evaluations.submit_evaluation(participant_scope, completed_registration.id, %{
                 overall_rating: 5
               })

      {:ok, _lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/completion")

      assert html =~ "Completion criteria"
      assert html =~ "Completed"
      assert html =~ "Pending Evaluation"
      assert html =~ "Eligible for certificate"
      assert html =~ "Certificate readiness"
      assert html =~ "Ready for release from the certificate register"
    end
  end
end
