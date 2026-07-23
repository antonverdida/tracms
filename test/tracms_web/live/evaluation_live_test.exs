defmodule TracmsWeb.EvaluationLiveTest do
  use TracmsWeb.ConnCase

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.EvaluationsFixtures

  alias Tracms.Attendance
  alias Tracms.Evaluations

  describe "participant evaluation flow" do
    test "submits an evaluation from my registrations", %{conn: conn} do
      manager = Tracms.TrainingsFixtures.training_manager_scope_fixture("training_coordinator")
      training_activity = evaluable_training_fixture_for_manager(manager.scope)

      registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      conn = log_in_user(conn, registration.registrant_user)

      {:ok, lv, html} =
        conn
        |> live(~p"/my/registrations/#{registration.id}/evaluation")

      assert html =~ training_activity.title

      html =
        lv
        |> form("#evaluation-form",
          evaluation_submission: %{
            overall_rating: "5",
            feedback: "Very useful content.",
            application_plan: "I will adapt the checklist in my office."
          }
        )
        |> render_submit()

      assert {:error, {:live_redirect, %{to: path}}} = html
      assert path == ~p"/my/registrations"

      {:ok, _lv, html} =
        {:error, {:live_redirect, %{to: path}}}
        |> follow_redirect(conn, path)

      assert html =~ "Submitted"
      assert html =~ "Update evaluation"
    end
  end

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
    end
  end
end
