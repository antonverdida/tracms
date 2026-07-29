defmodule TracmsWeb.TrainingLive.CertificatesTest do
  use TracmsWeb.ConnCase, async: false

  alias Tracms.Attendance
  alias Tracms.Certificates

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  test "view certificate opens the certificate preview page", %{conn: conn} do
    %{manager: manager, training: training, certificate: certificate} =
      issued_certificate_fixture()

    {:ok, view, _html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}")

    assert has_element?(
             view,
             "a[href='/certificates/trainings/#{training.id}/#{certificate.id}']",
             "View Certificate"
           )

    {:ok, _preview, preview_html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}/#{certificate.id}")

    assert preview_html =~ "Certificate Preview"
    assert preview_html =~ certificate.certificate_number
  end

  test "filters the certificate list by participant name", %{conn: conn} do
    %{
      manager: manager,
      training: training,
      participant: participant,
      attendance_session: attendance_session
    } =
      issued_certificate_fixture()

    other_participant = participant_scope_fixture()

    other_registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: other_participant,
        training_activity: training
      )

    {:ok, _attendance_record} =
      Attendance.mark_attendance(
        manager.scope,
        attendance_session.id,
        other_registration.id,
        %{
          status: :present
        }
      )

    {:ok, _other_certificate} =
      Certificates.issue_certificate(manager.scope, other_registration.id)

    {:ok, view, _html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}")

    html =
      view
      |> form("#certificate-search-form",
        certificate_search: %{query: participant.user.full_name}
      )
      |> render_change()

    assert html =~ participant.user.full_name
    refute html =~ other_participant.user.full_name
    assert html =~ "Download All Certificates"
  end

  test "uploaded certificate layout is displayed in the preview page", %{conn: conn} do
    %{manager: manager, participant: participant, training: training, certificate: certificate} =
      issued_certificate_fixture()

    %{scope: regional_scope} = training_manager_scope_fixture("regional_admin")

    {:ok, _layout_setting} =
      Certificates.update_default_certificate_layout(regional_scope, %{
        "certificate_size" => "legal_landscape",
        "asset_path" => "/uploads/certificate-layouts/live-preview-layout.png",
        "asset_name" => "live-preview-layout.png",
        "asset_content_type" => "image/png"
      })

    {:ok, _preview, preview_html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}/#{certificate.id}")

    assert preview_html =~ "/uploads/certificate-layouts/live-preview-layout.png"
    assert preview_html =~ "certificate-sheet-custom-layout"
    assert preview_html =~ participant.user.full_name
    assert preview_html =~ "data:image/svg+xml;base64,"
    assert preview_html =~ certificate.certificate_number
    assert preview_html =~ "/verify/certificates/#{certificate.certificate_number}"
  end

  test "uploaded certificate automatically adjusts font size for long participant names", %{
    conn: conn
  } do
    long_name = "Maria Cristina Evangelista Dela Cruz-Santos Villanueva Fernandez"

    manager = training_manager_scope_fixture()
    participant = participant_scope_fixture(%{full_name: long_name})
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
    %{scope: regional_scope} = training_manager_scope_fixture("regional_admin")

    {:ok, _layout_setting} =
      Certificates.update_default_certificate_layout(regional_scope, %{
        "certificate_size" => "legal_landscape",
        "asset_path" => "/uploads/certificate-layouts/live-preview-layout.png",
        "asset_name" => "live-preview-layout.png",
        "asset_content_type" => "image/png"
      })

    {:ok, _preview, preview_html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}/#{certificate.id}")

    assert preview_html =~ long_name
    assert preview_html =~ "certificate-sheet-custom-name-ultra-long"
    assert preview_html =~ "certificate-sheet-custom-nameplate-ultra-long"
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
      certificate: certificate,
      attendance_session: attendance_session
    }
  end
end
