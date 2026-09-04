defmodule Tracms.ReportsTest do
  use Tracms.DataCase, async: true

  alias Tracms.Attendance
  alias Tracms.Reports

  import Tracms.AttendanceFixtures
  import Tracms.TrainingsFixtures

  test "overview contains only records within the manager scope" do
    %{scope: scope} = manager = training_manager_scope_fixture()

    visible_training =
      published_training_fixture_for_manager(scope, %{title: "Visible accomplishment"})

    _hidden_training =
      training_activity_fixture(training_manager_scope_fixture().scope, %{
        title: "Hidden accomplishment"
      })

    participant = Tracms.RegistrationsFixtures.participant_scope_fixture()

    registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: visible_training
      )

    session =
      attendance_session_fixture(training_manager: manager, training_activity: visible_training)

    {:ok, session} = Attendance.open_session(scope, session)

    {:ok, _record} =
      Attendance.mark_attendance(scope, session.id, registration.id, %{status: :present})

    overview = Reports.overview(scope)

    assert [%{training: %{id: training_id}, registrations: 1, approved: 1, sessions: 1}] =
             overview.training_rows

    assert training_id == visible_training.id
    assert %{value: 1} = Enum.find(overview.registration_statuses, &(&1.label == "Approved"))
    assert %{value: 1} = Enum.find(overview.attendance_statuses, &(&1.label == "Open"))
  end
end
