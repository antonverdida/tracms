defmodule TracmsWeb.CertificateVerificationControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Certificates

  describe "public certificate verification" do
    test "shows the recorded certificate details", %{conn: conn} do
      %{participant: participant, certificate: certificate, training: training} =
        issued_certificate_fixture()

      conn = get(conn, ~p"/verify/certificates/#{certificate.certificate_number}")
      html = response(conn, 200)

      assert html =~ "VERIFIED CERTIFICATE RECORD"
      assert html =~ participant.user.full_name
      assert html =~ certificate.certificate_number
      assert html =~ training.title
    end

    test "search redirects to the matching certificate record", %{conn: conn} do
      %{certificate: certificate} = issued_certificate_fixture()

      conn =
        get(conn, ~p"/verify/certificates?certificate_number=#{certificate.certificate_number}")

      assert redirected_to(conn) == ~p"/verify/certificates/#{certificate.certificate_number}"
    end

    test "returns not found for an unknown certificate number", %{conn: conn} do
      conn = get(conn, ~p"/verify/certificates/TRACMS-UNKNOWN-999999")
      html = response(conn, 404)

      assert html =~ "CERTIFICATE NOT FOUND"
      assert html =~ "TRACMS-UNKNOWN-999999"
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
      registration: registration,
      certificate: certificate,
      attendance_session: attendance_session
    }
  end
end
