defmodule TracmsWeb.TrainingLive.ShowTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.TrainingsFixtures

  test "shows a complete training record from the View button destination", %{conn: conn} do
    %{scope: scope, user: user} = training_manager_scope_fixture()
    today = Date.utc_today()

    training =
      training_activity_fixture(scope, %{
        title: "Leadership Development Program",
        description: "Build leadership capability across school teams.",
        objectives: "Strengthen planning and coaching practices.",
        registration_opens_on: Date.add(today, -2),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 3, :day),
        starts_on: Date.add(today, 5),
        ends_on: Date.add(today, 7)
      })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/trainings/#{training.id}")

    assert has_element?(view, ".portal-page-title", training.title)
    assert has_element?(view, ".feature-title", "Schedule")
    assert has_element?(view, ".feature-title", "Objectives")
    assert has_element?(view, ".feature-title", "Attendance Monitoring")
    assert has_element?(view, "a[href='/trainings/#{training.id}/edit']", "Edit Training")
  end

  test "moves a published training through ongoing and completed delivery states", %{conn: conn} do
    %{scope: scope, user: user} = training_manager_scope_fixture()
    today = Date.utc_today()

    training =
      training_activity_fixture(scope, %{
        title: "Training Delivery Lifecycle",
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_opens_on: Date.add(today, -2),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 1, :day),
        starts_on: Date.add(today, 1),
        ends_on: Date.add(today, 3)
      })

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/trainings/#{training.id}")

    assert has_element?(view, "button[phx-click='update_training_status']", "Mark as Ongoing")

    html =
      view
      |> element(
        "button[phx-click='update_training_status'][phx-value-status='in_progress']",
        "Mark as Ongoing"
      )
      |> render_click()

    assert html =~ "Training status updated to Ongoing."
    assert has_element?(view, "button[phx-click='update_training_status']", "Mark as Completed")

    html =
      view
      |> element(
        "button[phx-click='update_training_status'][phx-value-status='completed']",
        "Mark as Completed"
      )
      |> render_click()

    assert html =~ "Training status updated to Completed."
    assert html =~ "Delivery is finished."
  end
end
