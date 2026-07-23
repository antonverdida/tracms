defmodule Tracms.AttendanceTest do
  use Tracms.DataCase

  alias Tracms.Attendance

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "attendance sessions" do
    test "create_session/3 creates a draft attendance session for a manager training" do
      manager = training_manager_scope_fixture()
      training_activity = published_training_fixture_for_manager(manager.scope)

      assert {:ok, attendance_session} =
               Attendance.create_session(manager.scope, training_activity.id, %{
                 name: "Day 1 AM",
                 session_date: training_activity.starts_on,
                 starts_at: ~T[08:00:00],
                 ends_at: ~T[12:00:00]
               })

      assert attendance_session.training_activity_id == training_activity.id
      assert attendance_session.status == :draft
    end

    test "list_session_roster/2 only includes approved registrations" do
      manager = training_manager_scope_fixture()
      training_activity = published_training_fixture_for_manager(manager.scope)

      attendance_session =
        attendance_session_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      approved_registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      participant = participant_scope_fixture()

      {:ok, _submitted_registration} =
        Tracms.Registrations.register_user_for_training(participant.scope, training_activity.id)

      roster = Attendance.list_session_roster(manager.scope, attendance_session.id)

      assert Enum.map(roster, & &1.registration.id) == [approved_registration.id]
    end

    test "mark_attendance/4 upserts the attendance record for an approved participant" do
      manager = training_manager_scope_fixture()
      training_activity = published_training_fixture_for_manager(manager.scope)

      registration =
        approved_registration_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      attendance_session =
        attendance_session_fixture(
          training_manager: manager,
          training_activity: training_activity
        )

      assert {:ok, attendance_session} =
               Attendance.open_session(manager.scope, attendance_session)

      assert {:ok, attendance_record} =
               Attendance.mark_attendance(
                 manager.scope,
                 attendance_session.id,
                 registration.id,
                 %{status: :present}
               )

      assert attendance_record.status == :present

      assert {:ok, updated_record} =
               Attendance.mark_attendance(
                 manager.scope,
                 attendance_session.id,
                 registration.id,
                 %{status: :late}
               )

      assert updated_record.id == attendance_record.id
      assert updated_record.status == :late
    end
  end
end
