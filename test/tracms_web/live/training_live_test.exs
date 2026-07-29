defmodule TracmsWeb.TrainingLiveTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.TrainingsFixtures

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

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings")

      assert html =~ "Training Activities"
      assert html =~ "Training Management 101"
      assert html =~ "View"
      assert html =~ "/trainings/#{training_activity.id}"
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
            description: "Summit description",
            objectives: "Improve literacy program delivery and assessment planning.",
            category: "Curriculum and Instruction",
            training_type: "Professional Development Program",
            organizer: "DepEd Region IX",
            modality: "face_to_face",
            venue: "Zamboanga Peninsula",
            venue_address: "Pagadian City, Zamboanga del Sur",
            total_hours: "24",
            target_participants: "Teachers and school heads",
            participant_qualification: "Must be endorsed by the school head.",
            registration_opens_on: "2026-07-20",
            registration_deadline: "2026-08-01T09:00",
            max_capacity: 150,
            starts_on: "2026-08-10",
            ends_on: "2026-08-12",
            attendance_monitoring_method: "QR Code and Manual Verification",
            certificate_type: "Certificate of Participation",
            registration_form_url: "https://forms.gle/tracms-registration",
            attendance_form_url: "https://forms.gle/tracms-attendance",
            registration_sheet_id: "sync-sheet-main",
            registration_sheet_range: "Form Responses 1!A:F",
            attendance_sheet_id: "attendance-sheet-main",
            attendance_sheet_range: "Attendance!A:C"
          }
        )

      assert {:error, {:live_redirect, %{to: path}}} = render_submit(form)
      assert path =~ "/trainings/"

      {:ok, _lv, html} =
        {:error, {:live_redirect, %{to: path}}}
        |> follow_redirect(conn, path)

      assert html =~ "Regional Literacy Summit"
      assert html =~ "Training details"
      assert html =~ "Government training record"
      assert html =~ "Google Workspace integration"
      assert html =~ "Open integration module"
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

      {:ok, _lv, html} =
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
      assert html =~ "Sync registration intake"
      assert html =~ "Review intake queue"
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

      assert html =~ "Generate registration form"
      assert html =~ "Generate attendance form"

      html =
        lv
        |> element(
          "button[phx-click=\"generate_registration_form\"]",
          "Generate registration form"
        )
        |> render_click()

      assert html =~ "Google registration form generated successfully."
      assert html =~ "Manage in Google Forms"
      assert html =~ "Open registration form"

      html =
        lv
        |> element("button[phx-click=\"generate_attendance_form\"]", "Generate attendance form")
        |> render_click()

      assert html =~ "Google attendance form generated successfully."
      assert html =~ "Open attendance form"
      assert html =~ "Manage in Google Forms"
    end
  end
end
