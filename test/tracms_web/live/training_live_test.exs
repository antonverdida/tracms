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
      training_activity_fixture(scope, %{title: "Training Management 101"})

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/trainings")

      assert html =~ "Training Activities"
      assert html =~ "Training Management 101"
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
            certificate_type: "Certificate of Participation"
          }
        )

      assert {:error, {:live_redirect, %{to: path}}} = render_submit(form)
      assert path =~ "/trainings/"

      {:ok, _lv, html} =
        {:error, {:live_redirect, %{to: path}}}
        |> follow_redirect(conn, path)

      assert html =~ "Regional Literacy Summit"
      assert html =~ "Training details"
    end
  end
end
