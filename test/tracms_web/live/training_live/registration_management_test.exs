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

    assert html =~ "Registration Management"
    assert html =~ "Managed Trainings"
    assert html =~ "Digital Education Trends"
    assert html =~ "View"
    refute html =~ "Registered Participants"
    refute html =~ "Pending review"
    refute html =~ "Approved participants"
    refute html =~ "Rejected"
    assert html =~ "/registrations/trainings/#{training_activity.id}"
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
    assert html =~ "Back to registrations"
    refute html =~ participant.user.email
  end
end
