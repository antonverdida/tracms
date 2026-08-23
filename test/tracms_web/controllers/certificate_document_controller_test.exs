defmodule TracmsWeb.CertificateDocumentControllerTest do
  use TracmsWeb.ConnCase

  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Trainings

  describe "manager certificate documents" do
    test "training manager can open the print document", %{conn: conn} do
      %{manager: manager, participant: participant, training: training, certificate: certificate} =
        issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/certificates/trainings/#{training.id}/#{certificate.id}/print")

      html = response(conn, 200)

      assert html =~ participant.user.full_name
      assert html =~ certificate.certificate_number
      assert html =~ "No certificate layout uploaded yet"
      assert html =~ "Back to Certificate Records"
      assert html =~ "@page { size: A4 landscape; margin: 0; }"
    end

    test "training manager can download a single certificate as pdf", %{conn: conn} do
      %{manager: manager, training: training, certificate: certificate} =
        issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/certificates/trainings/#{training.id}/#{certificate.id}/export")

      pdf_binary = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["application/pdf; charset=utf-8"]
      assert String.starts_with?(pdf_binary, "%PDF")
    end

    test "training manager can download all certificates as a zip archive", %{conn: conn} do
      manager = training_manager_scope_fixture()
      participant = participant_scope_fixture()
      other_participant = participant_scope_fixture()
      training = certificate_window_training_fixture(manager.scope)

      registration =
        approved_registration_fixture(
          training_manager: manager,
          participant: participant,
          training_activity: training
        )

      other_registration =
        approved_registration_fixture(
          training_manager: manager,
          participant: other_participant,
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

      {:ok, _attendance_record} =
        Attendance.mark_attendance(manager.scope, attendance_session.id, other_registration.id, %{
          status: :present
        })

      training = complete_training!(manager.scope, training)

      {:ok, certificate} = Certificates.issue_certificate(manager.scope, registration.id)

      {:ok, other_certificate} =
        Certificates.issue_certificate(manager.scope, other_registration.id)

      conn =
        conn
        |> log_in_user(manager.user)
        |> get(~p"/certificates/trainings/#{training.id}/download-all")

      zip_binary = response(conn, 200)

      [content_disposition] = get_resp_header(conn, "content-disposition")
      assert content_disposition =~ "attachment;"
      assert content_disposition =~ "tracms-certificates-"

      archive_path = Path.join(System.tmp_dir!(), "tracms-certificates-test.zip")
      File.write!(archive_path, zip_binary)
      {:ok, files} = :zip.extract(String.to_charlist(archive_path), [:memory])

      filenames =
        Enum.map(files, fn {name, _contents} -> List.to_string(name) end)

      assert "tracms-certificate-#{certificate_number_slug(certificate.certificate_number)}.pdf" in filenames

      assert "tracms-certificate-#{certificate_number_slug(other_certificate.certificate_number)}.pdf" in filenames

      file_contents =
        files
        |> Enum.map(fn {name, contents} ->
          {List.to_string(name), IO.iodata_to_binary(contents)}
        end)
        |> Map.new()

      assert String.starts_with?(
               file_contents[
                 "tracms-certificate-#{certificate_number_slug(certificate.certificate_number)}.pdf"
               ],
               "%PDF"
             )

      assert String.starts_with?(
               file_contents[
                 "tracms-certificate-#{certificate_number_slug(other_certificate.certificate_number)}.pdf"
               ],
               "%PDF"
             )
    end

    test "non-managers are redirected away from manager document routes", %{conn: conn} do
      %{participant: participant, training: training, certificate: certificate} =
        issued_certificate_fixture()

      conn =
        conn
        |> log_in_user(participant.user)
        |> get(~p"/certificates/trainings/#{training.id}/#{certificate.id}/print")

      assert redirected_to(conn) == ~p"/dashboard"
    end
  end

  defp issued_certificate_fixture do
    manager = training_manager_scope_fixture()
    participant = participant_scope_fixture()
    training = certificate_window_training_fixture(manager.scope)

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

    training = complete_training!(manager.scope, training)
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

  defp certificate_window_training_fixture(scope) do
    today = Date.utc_today()

    published_training_fixture_for_manager(scope, %{
      registration_opens_on: Date.add(today, -2),
      registration_deadline: DateTime.add(DateTime.utc_now(:second), 2, :day),
      starts_on: Date.add(today, 3),
      ends_on: Date.add(today, 5)
    })
  end

  defp complete_training!(scope, training) do
    {:ok, training} = Trainings.update_training_status(scope, training, :in_progress)
    {:ok, training} = Trainings.update_training_status(scope, training, :completed)
    training
  end

  defp certificate_number_slug(certificate_number) do
    certificate_number
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
