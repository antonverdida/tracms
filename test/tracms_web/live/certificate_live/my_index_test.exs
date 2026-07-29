defmodule TracmsWeb.CertificateLive.MyIndexTest do
  use TracmsWeb.ConnCase, async: true

  alias Tracms.Attendance
  alias Tracms.Certificates

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "/certificates" do
    test "renders certificate management overview for training managers", %{conn: conn} do
      %{manager: manager, training: training} =
        issued_certificate_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/certificates")

      assert html =~ "Certificate Management"
      assert html =~ "Managed Trainings"
      assert html =~ training.title
      assert html =~ "1"
      assert html =~ "participant"
      assert html =~ "View"
    end

    test "renders personal certificate history for participants", %{conn: conn} do
      %{participant: participant, training: training, certificate: certificate} =
        issued_certificate_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(participant.user)
        |> live(~p"/certificates")

      assert html =~ "Issued Certificates"
      assert html =~ training.title
      assert html =~ certificate.certificate_number
      assert html =~ "View certificate"
      refute html =~ "Certificate Management"
    end
  end

  defp issued_certificate_fixture do
    manager = training_manager_scope_fixture()
    participant = participant_scope_fixture()
    training = published_training_fixture_for_manager(manager.scope)

    registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    attendance_session =
      attendance_session_fixture(
        training_manager: manager,
        training_activity: training
      )

    {:ok, attendance_session} = Attendance.open_session(manager.scope, attendance_session)

    {:ok, _attendance_record} =
      Attendance.mark_attendance(manager.scope, attendance_session.id, registration.id, %{
        status: :present
      })

    {:ok, certificate} = Certificates.issue_certificate(manager.scope, registration.id)

    %{
      manager: manager,
      participant: participant,
      training: training,
      certificate: certificate
    }
  end
end
