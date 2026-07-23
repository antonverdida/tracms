defmodule Tracms.EvaluationsFixtures do
  @moduledoc """
  Test helpers for the Evaluations context.
  """

  alias Tracms.Evaluations

  import Tracms.AttendanceFixtures

  def evaluable_training_fixture_for_manager(scope) do
    Tracms.TrainingsFixtures.training_activity_fixture(scope, %{
      status: :published,
      published_at: DateTime.utc_now(:second),
      registration_deadline: DateTime.add(DateTime.utc_now(:second), 7, :day),
      starts_on: Date.add(Date.utc_today(), 14),
      ends_on: Date.add(Date.utc_today(), 16),
      evaluation_required: true,
      minimum_attendance_percentage: 75
    })
  end

  def evaluation_submission_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    training_manager =
      Map.get_lazy(attrs, :training_manager, fn ->
        Tracms.TrainingsFixtures.training_manager_scope_fixture()
      end)

    training_activity =
      Map.get_lazy(attrs, :training_activity, fn ->
        evaluable_training_fixture_for_manager(training_manager.scope)
      end)

    registration =
      Map.get_lazy(attrs, :registration, fn ->
        approved_registration_fixture(
          training_manager: training_manager,
          training_activity: training_activity
        )
      end)

    {:ok, evaluation_submission} =
      Evaluations.submit_evaluation(
        registration.registrant_user |> Tracms.Accounts.Scope.for_user(),
        registration.id,
        %{
          overall_rating: Map.get(attrs, :overall_rating, 5),
          feedback: Map.get(attrs, :feedback, "Useful and practical training."),
          application_plan:
            Map.get(attrs, :application_plan, "I will apply the strategy in my next session.")
        }
      )

    evaluation_submission
  end
end
