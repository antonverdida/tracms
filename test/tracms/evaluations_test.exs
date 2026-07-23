defmodule Tracms.EvaluationsTest do
  use Tracms.DataCase

  alias Tracms.Attendance
  alias Tracms.Evaluations

  import Tracms.AttendanceFixtures
  import Tracms.EvaluationsFixtures

  describe "evaluation submissions" do
    test "submit_evaluation/3 creates and updates an evaluation submission" do
      manager = Tracms.TrainingsFixtures.training_manager_scope_fixture()
      training_activity = evaluable_training_fixture_for_manager(manager.scope)

      registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      participant_scope = Tracms.Accounts.Scope.for_user(registration.registrant_user)

      assert {:ok, submission} =
               Evaluations.submit_evaluation(participant_scope, registration.id, %{
                 overall_rating: 4,
                 feedback: "Strong training content."
               })

      assert submission.overall_rating == 4

      assert {:ok, updated_submission} =
               Evaluations.submit_evaluation(participant_scope, registration.id, %{
                 overall_rating: 5,
                 application_plan: "I will reuse the planning template."
               })

      assert updated_submission.id == submission.id
      assert updated_submission.overall_rating == 5
    end
  end

  describe "completion summary" do
    test "list_training_completion/2 combines attendance and evaluation rules" do
      manager = Tracms.TrainingsFixtures.training_manager_scope_fixture()
      training_activity = evaluable_training_fixture_for_manager(manager.scope)

      completed_registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      pending_eval_registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      insufficient_registration =
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
               Attendance.mark_attendance(
                 manager.scope,
                 session.id,
                 pending_eval_registration.id,
                 %{status: :present}
               )

      assert {:ok, _} =
               Attendance.mark_attendance(
                 manager.scope,
                 session.id,
                 insufficient_registration.id,
                 %{status: :absent}
               )

      participant_scope = Tracms.Accounts.Scope.for_user(completed_registration.registrant_user)

      assert {:ok, _submission} =
               Evaluations.submit_evaluation(participant_scope, completed_registration.id, %{
                 overall_rating: 5
               })

      entries = Evaluations.list_training_completion(manager.scope, training_activity.id)

      completed_entry = Enum.find(entries, &(&1.registration.id == completed_registration.id))

      pending_eval_entry =
        Enum.find(entries, &(&1.registration.id == pending_eval_registration.id))

      insufficient_entry =
        Enum.find(entries, &(&1.registration.id == insufficient_registration.id))

      assert completed_entry.completion_status == :completed
      assert pending_eval_entry.completion_status == :pending_evaluation
      assert insufficient_entry.completion_status == :insufficient_attendance
    end
  end
end
