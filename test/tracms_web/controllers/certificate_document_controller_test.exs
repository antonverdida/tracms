defmodule TracmsWeb.CertificateDocumentControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Repo

  describe "participant certificate documents" do
    test "print view acknowledges participant access", %{conn: conn} do
      %{participant: participant, certificate: certificate} = issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(participant.user)
        |> get(~p"/my/certificates/#{certificate.id}/print")

      html = response(conn, 200)

      assert html =~ "Official certificate document"
      assert html =~ certificate.certificate_number
      assert html =~ "Print certificate"

      assert Repo.get!(CertificateRecord, certificate.id).delivery_status == :downloaded
    end

    test "export downloads the certificate document", %{conn: conn} do
      %{participant: participant, certificate: certificate} = issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(participant.user)
        |> get(~p"/my/certificates/#{certificate.id}/export")

      html = response(conn, 200)

      assert html =~ "<!DOCTYPE html>"
      assert html =~ certificate.certificate_number

      [content_disposition] = get_resp_header(conn, "content-disposition")
      assert content_disposition =~ "attachment;"
      assert content_disposition =~ "tracms-certificate-"
    end
  end

  describe "manager certificate documents" do
    test "training manager can open the print document", %{conn: conn} do
      %{manager: manager, participant: participant, training: training, certificate: certificate} =
        issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/trainings/#{training.id}/certificates/#{certificate.id}/print")

      html = response(conn, 200)

      assert html =~ participant.user.full_name
      assert html =~ certificate.certificate_number
      assert html =~ "Back to preview"
    end

    test "non-managers are redirected away from manager document routes", %{conn: conn} do
      %{participant: participant, training: training, certificate: certificate} =
        issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(participant.user)
        |> get(~p"/trainings/#{training.id}/certificates/#{certificate.id}/print")

      assert redirected_to(conn) == ~p"/dashboard"
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
      certificate: certificate
    }
  end
end
