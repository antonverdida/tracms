defmodule TracmsWeb.TrainingLiveTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.TrainingsFixtures

  alias Tracms.Certificates

  describe "training management access" do
    test "redirects a logged-in user without training manager role", %{conn: conn} do
      user = Tracms.AccountsFixtures.user_fixture()

      {:ok, _conn} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings")
        |> follow_redirect(conn, ~p"/dashboard")
    end
  end

  describe "training management pages" do
    test "renders the training list for a manager", %{conn: conn} do
      %{scope: scope, user: user} = training_manager_scope_fixture()
      training_activity = training_activity_fixture(scope, %{title: "Training Management 101"})

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings")

      assert html =~ "Training Activities"
      assert html =~ "Training Management 101"
      assert has_element?(lv, "#training-#{training_activity.id}.ui-card")

      assert has_element?(
               lv,
               "a.btn-secondary[href='/trainings/#{training_activity.id}']",
               "View"
             )
    end

    test "advances a draft training from its detail page", %{conn: conn} do
      %{scope: scope, user: user} = training_manager_scope_fixture()
      training_activity = training_activity_fixture(scope)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings/#{training_activity.id}")

      assert has_element?(lv, "button[phx-click=\"advance_training\"]", "Submit to division")

      lv
      |> element("button[phx-click=\"advance_training\"]", "Submit to division")
      |> render_click()

      assert has_element?(lv, ".portal-chip", "Pending Division Approval")
    end

    test "creates a training activity from the form", %{conn: conn} do
      %{user: user} = training_manager_scope_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} =
        conn
        |> live(~p"/trainings/new")

      form =
        form(lv, "#training-form",
          training_activity: %{
            title: "Regional Literacy Summit",
            category: "Curriculum and Instruction",
            training_type: "Professional Development Program",
            organizer: "DepEd Region IX",
            modality: "face_to_face",
            resource_speaker: "Regional Literacy Team",
            venue: "Zamboanga Peninsula",
            venue_address: "Pagadian City, Zamboanga del Sur",
            total_hours: "24",
            start_time: "08:00",
            end_time: "17:00",
            registration_opens_on: "2026-07-20",
            registration_deadline: "2026-08-01T09:00",
            max_capacity: 150,
            starts_on: "2026-08-10",
            ends_on: "2026-08-12",
            attendance_monitoring_method: "QR Code and Manual Verification",
            certificate_type: "Certificate of Participation",
            registration_form_url: "https://forms.gle/tracms-registration",
            registration_sheet_id: "sync-sheet-main",
            registration_sheet_range: "Form Responses 1!A:F"
          }
        )

      render_submit(form)

      assert has_element?(lv, "#training-created-confirmation")
      assert has_element?(lv, "#training-created-confirmation", "Regional Literacy Summit")

      html = render(lv)

      refute html =~ "Registration workspace"

      refute html =~
               "Use this training-specific workspace to review registrations and registered participants."

      assert has_element?(lv, "a[href^='/trainings/']", "View Training")
    end

    test "shows a drag-and-drop certificate layout upload area for a regional administrator", %{
      conn: conn
    } do
      %{user: user} = training_manager_scope_fixture("regional_admin")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} =
        conn
        |> live(~p"/trainings/new")

      assert has_element?(lv, "#certificate-layout-dropzone[phx-drop-target]")

      assert has_element?(
               lv,
               "#certificate-layout-dropzone input[type='file'][data-phx-upload-ref]"
             )

      assert has_element?(
               lv,
               "#certificate-layout-dropzone input[type='file'][data-phx-auto-upload]"
             )

      assert has_element?(
               lv,
               "#certificate-layout-dropzone input[type='file'].certificate-layout-upload-input"
             )
    end

    test "uploads a certificate layout and creates a training for a regional administrator", %{
      conn: conn
    } do
      %{user: user} = training_manager_scope_fixture("regional_admin")
      conn = log_in_user(conn, user)

      {:ok, lv, _html} =
        conn
        |> live(~p"/trainings/new")

      assert has_element?(lv, "#save-training-button:not([disabled])")

      lv
      |> file_input("#certificate-layout-form", :certificate_layout_asset, [
        %{
          last_modified: 1_724_486_400_000,
          name: "certificate-layout.png",
          content: "certificate image content",
          type: "image/png"
        }
      ])
      |> render_upload("certificate-layout.png")

      assert has_element?(lv, "#certificate-layout-save-confirmation")
      assert has_element?(lv, "#flash-info", "Certificate layout saved automatically.")
      assert has_element?(lv, "#save-training-button:not([disabled])")

      layout = Certificates.get_default_certificate_layout_setting()
      assert layout.asset_name == "certificate-layout.png"
      assert layout.asset_path == "database://default"
      assert layout.asset_data == "certificate image content"
      assert layout.asset_size == byte_size("certificate image content")

      training_form =
        form(lv, "#training-form",
          training_activity: %{
            title: "Layout-Ready Training",
            category: "Teacher Development",
            training_type: "Capacity Building Training",
            organizer: "DepEd Region IX",
            modality: "face_to_face",
            venue: "Regional Learning Center",
            venue_address: "Pagadian City",
            attendance_monitoring_method: "QR Code and Manual Verification",
            certificate_type: "Certificate of Participation",
            minimum_attendance_percentage: "75",
            evaluation_required: "false"
          }
        )

      render_submit(training_form)

      assert has_element?(lv, "#training-created-confirmation")
      assert has_element?(lv, "a[href='/trainings']", "Back to List of Trainings")
      assert has_element?(lv, "a[href^='/trainings/']", "View Training")
    end

    test "hides certificate document-control settings for a regional administrator", %{conn: conn} do
      %{user: user} = training_manager_scope_fixture("regional_admin")

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings/new")

      assert has_element?(lv, "#certificate-layout-form")
      assert has_element?(lv, "select[name='certificate_layout_setting[certificate_size]']")
      refute has_element?(lv, "input[name='certificate_layout_setting[document_reference_code]']")
      refute has_element?(lv, "input[name='certificate_layout_setting[revision_number]']")
      refute has_element?(lv, "input[name='certificate_layout_setting[effectivity_date]']")
    end

    test "renders the Google Workspace integration page for a training", %{conn: conn} do
      %{scope: scope, user: user} = training_manager_scope_fixture()

      training_activity =
        training_activity_fixture(scope, %{
          title: "Digital Education Trends",
          registration_form_url: "https://forms.gle/tracms-registration",
          attendance_form_url: "https://forms.gle/tracms-attendance",
          registration_sheet_id: "sync-sheet-main",
          registration_sheet_range: "Form Responses 1!A:F",
          attendance_sheet_id: "attendance-sheet-main",
          attendance_sheet_range: "Attendance!A:C",
          evaluation_required: true
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings/#{training_activity.id}/integrations")

      assert html =~ "Google Workspace integration"
      assert html =~ "Registration Form"
      assert html =~ "Registration Response Sheet"
      assert html =~ "Attendance Form"
      assert html =~ "Attendance Response Sheet"
      assert html =~ "Evaluation Workflow"
      assert html =~ "Connected"
      assert html =~ "TRACMS internal"
      assert html =~ "Sync Registration Intake"
      assert html =~ "Review Intake Queue"
      assert has_element?(lv, "button", "Configure Integrations")
    end

    test "saves registration and attendance integration settings", %{conn: conn} do
      %{scope: scope, user: user} = training_manager_scope_fixture()
      training_activity = training_activity_fixture(scope)

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings/#{training_activity.id}/integrations")

      lv
      |> element("button", "Configure Integrations")
      |> render_click()

      assert has_element?(lv, "#integration-configuration-form")

      html =
        lv
        |> form("#integration-configuration-form",
          training_activity: %{
            registration_form_url: "https://forms.google.com/registration",
            registration_sheet_id: "registration-sheet-id",
            registration_sheet_range: "Form Responses 1!A:F",
            attendance_form_url: "https://forms.google.com/attendance",
            attendance_sheet_id: "attendance-sheet-id",
            attendance_sheet_range: "Attendance!A:C"
          }
        )
        |> render_submit()

      assert html =~ "Registration and attendance integrations updated."
      assert html =~ "registration-sheet-id"
      assert html =~ "attendance-sheet-id"
      refute has_element?(lv, "#integration-configuration-form")
    end

    test "generates registration and attendance Google Forms from the integration page", %{
      conn: conn
    } do
      %{scope: scope, user: user} = training_manager_scope_fixture()

      training_activity =
        training_activity_fixture(scope, %{
          title: "Google Forms Automation Pilot",
          status: :published,
          published_at: DateTime.utc_now(:second)
        })

      {:ok, lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings/#{training_activity.id}/integrations")

      assert html =~ "Generate Registration Form"
      assert html =~ "Generate Attendance Form"

      html =
        lv
        |> element(
          "button[phx-click=\"generate_registration_form\"]",
          "Generate Registration Form"
        )
        |> render_click()

      assert html =~ "Google registration form generated successfully."
      assert html =~ "Manage in Google Forms"
      assert html =~ "Open Registration Form"

      html =
        lv
        |> element("button[phx-click=\"generate_attendance_form\"]", "Generate Attendance Form")
        |> render_click()

      assert html =~ "Google attendance form generated successfully."
      assert html =~ "Open Attendance Form"
      assert html =~ "Manage in Google Forms"
    end
  end
end
