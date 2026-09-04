defmodule Tracms.AuditTest do
  use Tracms.DataCase, async: true

  alias Tracms.Attendance
  alias Tracms.Audit
  alias Tracms.Audit.AuditLog
  alias Tracms.Certificates
  alias Tracms.Repo

  import Tracms.AttendanceFixtures
  import Tracms.TrainingsFixtures

  test "records attendance changes and certificate issuance with the responsible actor" do
    %{scope: scope, user: user} = manager = training_manager_scope_fixture("regional_admin")
    training = published_training_fixture_for_manager(scope)
    participant = Tracms.RegistrationsFixtures.participant_scope_fixture()

    registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    registration_log =
      Repo.get_by!(AuditLog, action: "registration_reviewed", entity_id: registration.id)

    assert registration_log.actor_user_id == user.id
    assert registration_log.metadata["to_status"] == "approved"

    session = attendance_session_fixture(training_manager: manager, training_activity: training)
    {:ok, session} = Attendance.open_session(scope, session)

    {:ok, record} =
      Attendance.mark_attendance(scope, session.id, registration.id, %{status: :present})

    attendance_log = Repo.get_by!(AuditLog, action: "attendance_marked", entity_id: record.id)
    assert attendance_log.actor_user_id == user.id
    assert attendance_log.training_activity_id == training.id
    assert attendance_log.metadata["status"] == "present"

    {:ok, training} =
      Tracms.Trainings.update_training_status(scope, training, :registration_closed)

    {:ok, training} = Tracms.Trainings.update_training_status(scope, training, :in_progress)
    {:ok, _training} = Tracms.Trainings.update_training_status(scope, training, :completed)
    {:ok, certificate} = Certificates.issue_certificate(scope, registration.id)

    certificate_log =
      Repo.get_by!(AuditLog, action: "certificate_issued", entity_id: certificate.id)

    assert certificate_log.actor_user_id == user.id
    assert certificate_log.metadata["certificate_number"] == certificate.certificate_number
  end

  test "lists audit entries only from trainings within the manager scope" do
    %{scope: scope} = manager = training_manager_scope_fixture()
    training = published_training_fixture_for_manager(scope)
    participant = Tracms.RegistrationsFixtures.participant_scope_fixture()

    _registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    other_manager = training_manager_scope_fixture()
    other_training = published_training_fixture_for_manager(other_manager.scope)
    other_participant = Tracms.RegistrationsFixtures.participant_scope_fixture()

    _other_registration =
      approved_registration_fixture(
        training_manager: other_manager,
        participant: other_participant,
        training_activity: other_training
      )

    audit_logs = Audit.list(scope)

    assert Enum.all?(audit_logs, &(&1.training_activity_id == training.id))
    assert Enum.any?(audit_logs, &(&1.action == "registration_reviewed"))
  end
end
