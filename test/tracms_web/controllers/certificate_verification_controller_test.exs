defmodule TracmsWeb.CertificateVerificationControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Repo
  alias Tracms.Trainings

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
      assert html =~ "No certificate layout uploaded yet"
    end

    test "validates a QR verification code on the public official route", %{conn: conn} do
      %{participant: participant, certificate: certificate} = issued_certificate_fixture()

      conn = get(conn, ~p"/verify/certificates/scan/#{certificate.verification_code}")
      html = response(conn, 200)

      assert html =~ "VERIFIED CERTIFICATE RECORD"
      assert html =~ participant.user.full_name
      assert html =~ certificate.certificate_number
    end

    test "does not accept a certificate number as a QR verification code", %{conn: conn} do
      %{certificate: certificate} = issued_certificate_fixture()

      conn = get(conn, ~p"/verify/certificates/scan/#{certificate.certificate_number}")
      html = response(conn, 404)

      assert html =~ "CERTIFICATE NOT FOUND"
    end

    test "rejects a revoked certificate verification code", %{conn: conn} do
      %{certificate: certificate} = issued_certificate_fixture()

      certificate
      |> CertificateRecord.changeset(%{verification_status: :revoked})
      |> Repo.update!()

      conn = get(conn, ~p"/verify/certificates/scan/#{certificate.verification_code}")
      html = response(conn, 404)

      assert html =~ "CERTIFICATE NOT FOUND"
      assert html =~ "has been revoked"
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
      assert html =~ "No valid TRACMS certificate record was found"
    end
  end

  defp issued_certificate_fixture do
    manager = training_manager_scope_fixture()
    participant = participant_scope_fixture()
    today = Date.utc_today()

    training =
      published_training_fixture_for_manager(manager.scope, %{
        registration_opens_on: Date.add(today, -2),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 2, :day),
        starts_on: Date.add(today, 3),
        ends_on: Date.add(today, 5)
      })

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

    {:ok, training} = Trainings.update_training_status(manager.scope, training, :in_progress)
    {:ok, training} = Trainings.update_training_status(manager.scope, training, :completed)
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
