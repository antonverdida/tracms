defmodule TracmsWeb.RegistrationLiveTest do
  use TracmsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "participant registration flow" do
    test "lists published trainings and opens the participant training details page", %{
      conn: conn
    } do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()
      conn = log_in_user(conn, participant.user)

      {:ok, lv, html} =
        conn
        |> live(~p"/catalog/trainings")

      assert html =~ training_activity.title

      assert {:error, {:live_redirect, %{to: path}}} =
               lv
               |> element("a", "View details")
               |> render_click()

      assert path == ~p"/catalog/trainings/#{training_activity.id}"

      {:ok, _lv, html} =
        {:error, {:live_redirect, %{to: path}}}
        |> follow_redirect(conn, path)

      assert html =~ "Participant training record"
      assert html =~ "Submit registration"
      assert html =~ training_activity.venue
    end

    test "submits a registration from the participant training details page", %{conn: conn} do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()
      conn = log_in_user(conn, participant.user)

      {:ok, lv, html} =
        conn
        |> live(~p"/catalog/trainings/#{training_activity.id}")

      assert html =~ "Submit registration"

      html =
        lv
        |> form("#participant-registration-form",
          registration_request: %{
            special_requirements: "Will need travel coordination support."
          }
        )
        |> render_submit()

      assert html =~ "Registration submitted successfully."
      assert html =~ "Registration progress"
      assert html =~ "Submitted"
    end

    test "shows the external registration workflow when a training uses an official form", %{
      conn: conn
    } do
      participant = participant_scope_fixture()

      training_activity =
        published_training_fixture(%{
          registration_form_url: "https://forms.gle/deped-registration",
          attendance_form_url: "https://forms.gle/deped-attendance"
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(participant.user)
        |> live(~p"/catalog/trainings/#{training_activity.id}")

      assert html =~ "Official external registration"
      assert html =~ "Open official registration form"
      refute has_element?(lv, "#participant-registration-form")

      assert has_element?(
               lv,
               "a[href=\"https://forms.gle/deped-registration\"]",
               "Open official registration form"
             )
    end

    test "shows user registrations", %{conn: conn} do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      {:ok, _registration} =
        Tracms.Registrations.register_user_for_training(participant.scope, training_activity.id)

      {:ok, _lv, html} =
        conn
        |> log_in_user(participant.user)
        |> live(~p"/my/registrations")

      assert html =~ training_activity.title
      assert html =~ "Submitted"
      assert html =~ "View training"
    end
  end

  describe "manager registration review flow" do
    test "allows a manager to review submitted registrations", %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day)
        })

      participant = participant_scope_fixture()

      {:ok, registration} =
        Tracms.Registrations.register_user_for_training(participant.scope, training_activity.id)

      {:ok, lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/registrations")

      assert html =~ registration.registrant_user.full_name

      html =
        lv
        |> element("button[phx-value-status=\"approved\"]", "Approve")
        |> render_click()

      assert html =~ "Registration updated successfully."
      assert html =~ "Approved"
    end

    test "lets a manager stage and import an external registration submission", %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")
      participant = participant_scope_fixture()

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration"
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/registrations")

      assert html =~ "External registration queue"

      html =
        lv
        |> form("#external-submission-form",
          external_submission: %{
            full_name: participant.user.full_name,
            email: participant.user.email,
            employee_number: participant.user.employee_number,
            office_name: participant.office.name,
            source_reference: "Google Sheet row 22",
            special_requirements: "Needs travel coordination."
          }
        )
        |> render_submit()

      assert html =~ "External registration submission added to the intake queue."
      assert html =~ "Google Sheet row 22"
      assert html =~ participant.user.email

      html =
        lv
        |> element("button[phx-click=\"import_external_submission\"]", "Import to TRACMS")
        |> render_click()

      assert html =~ "External submission imported into the TRACMS registration queue"
      assert html =~ "Registration decisions"
      assert html =~ "Submitted"
    end

    test "lets a manager bulk stage external registration submissions from pasted spreadsheet rows",
         %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")
      participant = participant_scope_fixture()

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration"
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/registrations")

      assert html =~ "Paste spreadsheet rows"

      tabular_data = """
      full_name\temail\temployee_number\toffice_name
      #{participant.user.full_name}\t#{participant.user.email}\t#{participant.user.employee_number}\t#{participant.office.name}
      Missing Email\t\tEMP-404\tUnknown Office
      """

      html =
        lv
        |> form("#bulk-import-form",
          bulk_import: %{
            batch_reference: "Google Sheet Batch",
            tabular_data: tabular_data
          }
        )
        |> render_submit()

      assert html =~
               "Bulk intake completed. 1 row(s) staged, 0 duplicate row(s) skipped, and 1 row(s) need correction."

      assert html =~ "Rows staged successfully"
      assert html =~ "Rows needing correction"
      assert html =~ participant.user.email
      assert html =~ "email can&#39;t be blank"
    end

    test "lets a manager sync external registration submissions from a configured Google Sheet",
         %{conn: conn} do
      manager = training_manager_scope_fixture("training_coordinator")

      _participant =
        participant_scope_fixture(%{
          email: "sync.participant@example.com",
          full_name: "Sync Participant",
          employee_number: "EMP-SYNC-1"
        })

      training_activity =
        training_activity_fixture(manager.scope, %{
          status: :published,
          published_at: DateTime.utc_now(:second),
          registration_deadline: DateTime.add(DateTime.utc_now(:second), 5, :day),
          registration_form_url: "https://forms.gle/deped-registration",
          registration_sheet_id: "sync-sheet-main",
          registration_sheet_range: "Form Responses 1!A:F"
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(manager.user)
        |> live(~p"/trainings/#{training_activity.id}/registrations")

      assert html =~ "Google Sheets sync status"
      assert html =~ "Ready"

      html =
        lv
        |> element("button[phx-click=\"sync_google_sheet\"]", "Sync Google Sheet now")
        |> render_click()

      assert html =~
               "Google Sheets sync completed. 1 row(s) staged, 0 duplicate row(s) skipped, and 1 row(s) need correction."

      assert html =~ "response-001"
      assert html =~ "sync.participant@example.com"
    end
  end
end
