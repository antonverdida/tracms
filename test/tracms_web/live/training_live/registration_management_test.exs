defmodule TracmsWeb.TrainingLive.RegistrationManagementTest do
  use TracmsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  test "renders registration management dashboard for training managers", %{conn: conn} do
    %{scope: scope, user: user} = training_manager_scope_fixture()

    training_activity =
      training_activity_fixture(scope, %{
        title: "Digital Education Trends",
        category: "Teacher Development",
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
        starts_on: Date.add(Date.utc_today(), 14),
        ends_on: Date.add(Date.utc_today(), 16),
        registration_form_url: "https://forms.gle/deped-registration",
        registration_sheet_id: "sheet-123",
        registration_sheet_range: "Form Responses 1!A:F"
      })

    {:ok, _registration} =
      Tracms.Registrations.register_user_for_training(
        participant_scope_fixture().scope,
        training_activity.id
      )

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/registrations")

    assert html =~ "List of Registration"
    assert html =~ "Choose a Training First"
    assert html =~ "Digital Education Trends"
    assert html =~ "View"
  end

  test "opens a training registration list directly, then allows manual add and filtering",
       %{
         conn: conn
       } do
    manager = training_manager_scope_fixture("training_coordinator")

    training_activity =
      training_activity_fixture(manager.scope, %{
        title: "Leadership for Learning",
        category: "School Leadership",
        status: :in_progress,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), -3, :day),
        starts_on: Date.add(Date.utc_today(), -2),
        ends_on: Date.add(Date.utc_today(), 1),
        description: "A full overview of the leadership pathway.",
        objectives: "Strengthen school leadership planning.",
        target_participants: "School heads and assistant principals.",
        participant_qualification: "Must currently handle school leadership duties."
      })

    {:ok, lv, html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/registrations")

    assert html =~ "Choose a Training First"

    lv
    |> element("a[href='/registrations?training_id=#{training_activity.id}&view=manage']", "View")
    |> render_click()

    assert_patch(lv, ~p"/registrations?training_id=#{training_activity.id}&view=manage")

    html = render(lv)

    assert html =~ "Add Participant Manually"
    assert html =~ "List of Registration"
    assert has_element?(lv, ".portal-page-title", "List of Registration")
    refute has_element?(lv, ".section-title")

    lv
    |> element("a[href='/registrations']", "Back")
    |> render_click()

    assert_patch(lv, ~p"/registrations")

    html = render(lv)

    assert html =~ "Choose a Training First"

    lv
    |> element("a[href='/registrations?training_id=#{training_activity.id}&view=manage']", "View")
    |> render_click()

    assert_patch(lv, ~p"/registrations?training_id=#{training_activity.id}&view=manage")

    html = render(lv)

    assert html =~ "Add Participant Manually"
    assert html =~ "Back"

    lv
    |> element("button[type=\"button\"][phx-click=\"show_manual_registration\"]")
    |> render_click()

    assert has_element?(lv, "#manual-registration-form")

    lv
    |> element("button[phx-click=\"cancel_manual_registration\"]", "Close")
    |> render_click()

    html =
      lv
      |> element("button", "Add Participant Manually")
      |> render_click()

    assert html =~ "Add Participants"

    html =
      lv
      |> form("#manual-registration-form",
        manual_registration: %{
          participant_names: "1. Master List Participant\n2) Additional Participant"
        }
      )
      |> render_submit()

    assert html =~ "Added 2 participants successfully."
    assert html =~ "Master List Participant"
    assert html =~ "Additional Participant"
    refute html =~ "1. Master List Participant"
    refute html =~ "2) Additional Participant"

    html =
      lv
      |> form("#registration-filters",
        filters: %{
          search: "Master List Participant"
        }
      )
      |> render_change()

    assert html =~ "Master List Participant"
    assert html =~ "Total Registrations"

    registration =
      Tracms.Registrations.list_manageable_registrations(manager.scope)
      |> Enum.find(&(&1.manual_participant_name == "Master List Participant"))

    assert registration.status == :approved

    html =
      lv
      |> element("button[phx-click=\"show_registration\"][phx-value-id=\"#{registration.id}\"]")
      |> render_click()

    assert html =~ "Participant information"
    assert html =~ "Back to Registration List"
    assert html =~ "Not provided"
    refute html =~ "Registration list"

    lv
    |> element("button[phx-click=\"hide_registration\"]", "Back to Registration List")
    |> render_click()

    html =
      lv
      |> element("button", "Add Participant Manually")
      |> render_click()

    assert html =~ "Add Participants"
    assert html =~ "Participant Names"
    assert has_element?(lv, "#manual-registration-form")
    refute html =~ "Participant information"
  end

  test "opens manual participant entry directly from the URL", %{conn: conn} do
    manager = training_manager_scope_fixture("training_coordinator")

    training_activity =
      training_activity_fixture(manager.scope, %{
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day)
      })

    {:ok, view, _html} =
      conn
      |> log_in_user(manager.user)
      |> live(~p"/registrations?training_id=#{training_activity.id}&view=manage&manual=true")

    assert has_element?(view, "#manual-registration-form")
    assert has_element?(view, "textarea[name=\"manual_registration[participant_names]\"]")
  end

  test "view route shows the participant names only", %{conn: conn} do
    %{scope: scope, user: user} = training_manager_scope_fixture()

    training_activity =
      training_activity_fixture(scope, %{
        title: "Leadership for Learning",
        category: "School Leadership",
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
        starts_on: Date.add(Date.utc_today(), 10),
        ends_on: Date.add(Date.utc_today(), 12)
      })

    participant = participant_scope_fixture()

    {:ok, _registration} =
      Tracms.Registrations.register_user_for_training(participant.scope, training_activity.id)

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/registrations/trainings/#{training_activity.id}")

    assert html =~ "Participant List"
    assert html =~ participant.user.full_name
    assert html =~ "Back to Registrations"
    refute html =~ participant.user.email
  end
end
