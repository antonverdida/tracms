defmodule TracmsWeb.TrainingLive.CertificatesTest do
  use TracmsWeb.ConnCase, async: false

  alias Tracms.Attendance
  alias Tracms.Certificates
  alias Tracms.Registrations
  alias Tracms.Trainings

  import Phoenix.LiveViewTest
  import Tracms.AttendanceFixtures
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  test "filters generated certificate records without a certificate detail page", %{conn: conn} do
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

    {:ok, _other_certificate} =
      Certificates.issue_certificate(manager.scope, other_registration.id)

    {:ok, view, _html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}")

    assert has_element?(view, "#certificate-filter-form")

    assert has_element?(
             view,
             "button[type=\"button\"][phx-click=\"show_manual_participant_form\"]",
             "Add Participant Manually"
           )

    refute has_element?(
             view,
             "a[href='/certificates/trainings/#{training.id}/#{certificate.id}']"
           )

    view
    |> element(
      "button[type=\"button\"][phx-click=\"show_manual_participant_form\"]",
      "Add Participant Manually"
    )
    |> render_click()

    assert has_element?(view, "#certificate-manual-participant-form")

    html =
      view
      |> form("#certificate-manual-participant-form",
        manual_participant: %{"participant_names" => "1. Certificate Page Participant"}
      )
      |> render_submit()

    assert html =~ "Certificate Page Participant"

    manual_entry =
      manager.scope
      |> Certificates.list_training_certificate_candidates(training.id)
      |> Enum.find(
        &(Registrations.participant_name(&1.registration) == "Certificate Page Participant")
      )

    assert manual_entry.attendance_record == nil
    assert manual_entry.eligible?
    assert manual_entry.certificate
    assert manual_entry.certificate.certificate_number =~ ~r/^\d{6}$/

    html =
      view
      |> form("#certificate-filter-form",
        certificate_filters: %{search: participant.user.full_name}
      )
      |> render_change()

    assert html =~ participant.user.full_name
    refute html =~ other_participant.user.full_name
    assert html =~ "Download PDF"

    view
    |> element("a[href='/certificates']", "Back")
    |> render_click()

    assert_patch(view, ~p"/certificates")
    assert has_element?(view, ".section-title", "Choose a Training First")
  end

  test "lists approved participants before a certificate is generated", %{conn: conn} do
    manager = training_manager_scope_fixture()
    participant = participant_scope_fixture()
    training = certificate_window_training_fixture(manager.scope)

    _registration =
      approved_registration_fixture(
        training_manager: manager,
        participant: participant,
        training_activity: training
      )

    training = complete_training!(manager.scope, training)

    {:ok, _view, html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}")

    assert html =~ "Participant Certificate Records"
    assert html =~ participant.user.full_name
    assert html =~ "Not Recorded"
    assert html =~ "Not Generated"
  end

  test "automatically generates certificates for manual participants added after completion", %{
    conn: conn
  } do
    manager = training_manager_scope_fixture()
    training = certificate_window_training_fixture(manager.scope)
    training = complete_training!(manager.scope, training)

    {:ok, [_registration]} =
      Registrations.create_manual_registrations(
        manager.scope,
        training.id,
        "1. Certificate Reconciliation Participant"
      )

    {:ok, _view, html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates?training_id=#{training.id}")

    assert html =~ "Certificate Reconciliation Participant"
    assert html =~ "Not Recorded"
    assert html =~ "Generated"
    assert html =~ ~r/\b\d{6}\b/
  end

  test "issues certificate numbers sequentially" do
    manager = training_manager_scope_fixture("regional_admin")

    training = completed_training_fixture_for_manager(manager.scope)

    {:ok, [first_registration, second_registration]} =
      Registrations.create_manual_registrations(
        manager.scope,
        training.id,
        "First Numbered Participant\nSecond Numbered Participant"
      )

    {:ok, first_certificate} =
      Certificates.issue_certificate(manager.scope, first_registration.id)

    {:ok, second_certificate} =
      Certificates.issue_certificate(manager.scope, second_registration.id)

    assert first_certificate.certificate_number == "000001"
    assert second_certificate.certificate_number == "000002"
  end

  test "generates certificates for all eligible participants from the page header", %{conn: conn} do
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

    {:ok, view, _html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/certificates/trainings/#{training.id}")

    html =
      view
      |> element("button[phx-click=\"generate_all_certificates\"]", "Generate All Certificates")
      |> render_click()

    assert html =~ "Generated 1 certificate."
    assert html =~ "Download PDF"
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
end
