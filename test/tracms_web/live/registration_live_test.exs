defmodule TracmsWeb.RegistrationLiveTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  describe "participant registration flow" do
    test "lists published trainings and lets a participant register", %{conn: conn} do
      participant = participant_scope_fixture()
      training_activity = published_training_fixture()

      {:ok, lv, html} =
        conn
        |> log_in_user(participant.user)
        |> live(~p"/catalog/trainings")

      assert html =~ training_activity.title

      html =
        lv
        |> element("button[phx-click=\"register\"]", "Register now")
        |> render_click()

      assert html =~ "Registration submitted successfully."
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
  end
end
