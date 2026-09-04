defmodule Tracms.Reports do
  @moduledoc """
  Read-only operational summaries for training managers.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Attendance.AttendanceSession
  alias Tracms.Evaluations
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings

  @registration_statuses Registration.status_values()
  @session_statuses AttendanceSession.status_values()
  @completion_statuses [
    :completed,
    :pending_evaluation,
    :insufficient_attendance,
    :awaiting_attendance
  ]

  def overview(scope) do
    if Scope.training_manager?(scope) do
      trainings = Trainings.list_training_activities(scope)
      training_ids = Enum.map(trainings, & &1.id)
      registrations_by_training_id = registration_summary_by_training(training_ids)
      sessions_by_training_id = session_summary_by_training(training_ids)
      completion_by_training_id = completion_summary_by_training(scope, trainings)

      training_rows =
        Enum.map(trainings, fn training ->
          registration_summary =
            Map.get(
              registrations_by_training_id,
              training.id,
              empty_summary(@registration_statuses)
            )

          session_summary =
            Map.get(sessions_by_training_id, training.id, empty_summary(@session_statuses))

          completion_summary =
            Map.get(completion_by_training_id, training.id, empty_summary(@completion_statuses))

          %{
            training: training,
            registrations: registration_summary.total,
            approved: registration_summary.approved,
            sessions: session_summary.total,
            completion_ready: completion_summary.completed
          }
        end)

      registration_summary =
        combine_summaries(registrations_by_training_id, @registration_statuses)

      session_summary = combine_summaries(sessions_by_training_id, @session_statuses)
      completion_summary = combine_summaries(completion_by_training_id, @completion_statuses)

      %{
        cards: [
          %{
            label: "Training activities",
            value: length(trainings),
            meta: "Within your management scope"
          },
          %{
            label: "Participant registrations",
            value: registration_summary.total,
            meta: "All recorded applications"
          },
          %{
            label: "Attendance sessions",
            value: session_summary.total,
            meta: "Open and closed sessions included"
          },
          %{
            label: "Completion-ready",
            value: completion_summary.completed,
            meta: "Meets attendance and evaluation rules"
          }
        ],
        training_rows: training_rows,
        registration_statuses: status_rows(registration_summary, @registration_statuses),
        attendance_statuses: status_rows(session_summary, @session_statuses),
        completion_statuses: status_rows(completion_summary, @completion_statuses)
      }
    else
      empty_overview()
    end
  end

  def format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp registration_summary_by_training([]), do: %{}

  defp registration_summary_by_training(training_ids) do
    Registration
    |> where([registration], registration.training_activity_id in ^training_ids)
    |> group_by([registration], [registration.training_activity_id, registration.status])
    |> select(
      [registration],
      {registration.training_activity_id, registration.status, count(registration.id)}
    )
    |> Repo.all()
    |> summarize_by_training(@registration_statuses)
  end

  defp session_summary_by_training([]), do: %{}

  defp session_summary_by_training(training_ids) do
    AttendanceSession
    |> where([session], session.training_activity_id in ^training_ids)
    |> group_by([session], [session.training_activity_id, session.status])
    |> select([session], {session.training_activity_id, session.status, count(session.id)})
    |> Repo.all()
    |> summarize_by_training(@session_statuses)
  end

  defp summarize_by_training(rows, statuses) do
    Enum.reduce(rows, %{}, fn {training_id, status, count}, summaries ->
      Map.update(
        summaries,
        training_id,
        summary_with_status(statuses, status, count),
        fn summary ->
          Map.update!(summary, status, &(&1 + count))
          |> Map.update!(:total, &(&1 + count))
        end
      )
    end)
  end

  defp completion_summary_by_training(scope, trainings) do
    Map.new(trainings, fn training ->
      summary =
        scope
        |> Evaluations.list_training_completion(training.id)
        |> Evaluations.completion_summary()

      {training.id, Map.put(summary, :total, Enum.sum(Map.values(summary)))}
    end)
  end

  defp combine_summaries(summaries, statuses) do
    Enum.reduce(summaries, empty_summary(statuses), fn {_training_id, summary}, totals ->
      Enum.reduce([:total | statuses], totals, fn key, acc ->
        Map.update!(acc, key, &(&1 + Map.fetch!(summary, key)))
      end)
    end)
  end

  defp status_rows(summary, statuses) do
    Enum.map(statuses, fn status ->
      %{label: format_status(status), value: Map.fetch!(summary, status)}
    end)
  end

  defp summary_with_status(statuses, status, count) do
    statuses
    |> empty_summary()
    |> Map.put(status, count)
    |> Map.put(:total, count)
  end

  defp empty_summary(statuses) do
    Map.new([:total | statuses], &{&1, 0})
  end

  defp empty_overview do
    registration_summary = empty_summary(@registration_statuses)

    %{
      cards: [],
      training_rows: [],
      registration_statuses: status_rows(registration_summary, @registration_statuses),
      attendance_statuses: status_rows(empty_summary(@session_statuses), @session_statuses),
      completion_statuses: status_rows(empty_summary(@completion_statuses), @completion_statuses)
    }
  end
end
