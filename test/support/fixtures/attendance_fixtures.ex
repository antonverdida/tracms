defmodule Tracms.AttendanceFixtures do
  @moduledoc """
  Test helpers for the Attendance context.
  """

  alias Tracms.Attendance
  alias Tracms.Registrations

  import Tracms.RegistrationsFixtures
  import Tracms.TrainingsFixtures

  def attendance_session_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    training_manager =
      Map.get_lazy(attrs, :training_manager, fn -> training_manager_scope_fixture() end)

    training_activity =
      Map.get_lazy(attrs, :training_activity, fn ->
        published_training_fixture_for_manager(training_manager.scope)
      end)

    {:ok, attendance_session} =
      Attendance.create_session(training_manager.scope, training_activity.id, %{
        name: Map.get(attrs, :name, "Day 1 AM"),
        session_date: Map.get(attrs, :session_date, training_activity.starts_on),
        starts_at: Map.get(attrs, :starts_at, ~T[08:00:00]),
        ends_at: Map.get(attrs, :ends_at, ~T[12:00:00])
      })

    attendance_session
  end

  def approved_registration_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    training_manager =
      Map.get_lazy(attrs, :training_manager, fn -> training_manager_scope_fixture() end)

    participant = Map.get_lazy(attrs, :participant, fn -> participant_scope_fixture() end)

    training_activity =
      Map.get_lazy(attrs, :training_activity, fn ->
        published_training_fixture_for_manager(training_manager.scope)
      end)

    {:ok, registration} =
      Registrations.register_user_for_training(
        participant.scope,
        training_activity.id,
        Map.get(attrs, :registration_attrs, %{})
      )

    {:ok, registration} =
      Registrations.review_registration(training_manager.scope, registration, :approved)

    registration
  end

  def published_training_fixture_for_manager(scope, attrs \\ %{}) do
    training_activity_fixture(
      scope,
      %{
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
        starts_on: Date.add(Date.utc_today(), 14),
        ends_on: Date.add(Date.utc_today(), 16)
      }
      |> Map.merge(Enum.into(attrs, %{}))
    )
  end
end
