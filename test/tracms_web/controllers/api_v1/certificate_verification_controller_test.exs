defmodule TracmsWeb.ApiV1.CertificateVerificationControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Certificates.CertificateRecord
  alias Tracms.Repo
  alias Tracms.Trainings

  describe "GET /api/v1/certificates/verify/:verification_code" do
    test "returns public verification data for a valid QR code", %{conn: conn} do
      %{certificate: certificate, participant: participant, training: training} =
        issued_certificate_fixture()

      response =
        conn
        |> get(~p"/api/v1/certificates/verify/#{certificate.verification_code}")
        |> json_response(200)

      certificate_data = response["data"]["verification"]["certificate"]

      assert response["data"]["verification"]["status"] == "valid"
      assert certificate_data["certificate_number"] == certificate.certificate_number
      assert certificate_data["holder_name"] == participant.user.full_name
      assert certificate_data["training_title"] == training.title
      refute Map.has_key?(certificate_data, "email")
      refute Map.has_key?(certificate_data, "employee_number")
    end

    test "returns gone for a revoked certificate", %{conn: conn} do
      %{certificate: certificate} = issued_certificate_fixture()

      certificate
      |> CertificateRecord.changeset(%{verification_status: :revoked})
      |> Repo.update!()

      response =
        conn
        |> get(~p"/api/v1/certificates/verify/#{certificate.verification_code}")
        |> json_response(410)

      assert response["error"]["code"] == "certificate_revoked"
    end

    test "returns not found for an invalid verification code", %{conn: conn} do
      response =
        conn
        |> get(~p"/api/v1/certificates/verify/not-a-valid-code")
        |> json_response(404)

      assert response["error"]["code"] == "certificate_not_found"
    end
  end

  describe "GET /api/v1/certificates" do
    test "verifies by certificate number", %{conn: conn} do
      %{certificate: certificate} = issued_certificate_fixture()

      response =
        conn
        |> get(~p"/api/v1/certificates?certificate_number=#{certificate.certificate_number}")
        |> json_response(200)

      assert response["data"]["verification"]["certificate"]["certificate_number"] ==
               certificate.certificate_number
    end

    test "requires a certificate number", %{conn: conn} do
      response = conn |> get(~p"/api/v1/certificates") |> json_response(400)

      assert response["error"]["code"] == "invalid_request"
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
      attendance_session_fixture(training_manager: manager, training_activity: training)

    {:ok, attendance_session} = Attendance.open_session(manager.scope, attendance_session)

    {:ok, _record} =
      Attendance.mark_attendance(manager.scope, attendance_session.id, registration.id, %{
        status: :present
      })

    {:ok, training} = Trainings.update_training_status(manager.scope, training, :in_progress)
    {:ok, training} = Trainings.update_training_status(manager.scope, training, :completed)
    {:ok, certificate} = Certificates.issue_certificate(manager.scope, registration.id)

    %{certificate: certificate, participant: participant, training: training}
  end
end
