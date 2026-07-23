defmodule Tracms.Evaluations do
  @moduledoc """
  The Evaluations context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Attendance.{AttendanceRecord, AttendanceSession}
  alias Tracms.Evaluations.EvaluationSubmission
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings

  @submission_preloads [
    registration: [training_activity: [], registrant_user: [:office, :role]],
    submitted_by_user: []
  ]
  @earned_attendance_statuses [:present, :late, :excused]

  def change_submission(%EvaluationSubmission{} = evaluation_submission, attrs \\ %{}) do
    EvaluationSubmission.changeset(evaluation_submission, attrs)
  end

  def get_user_registration_for_evaluation!(scope, registration_id) do
    registration =
      Registration
      |> preload(training_activity: [], registrant_user: [:office, :role])
      |> Repo.get!(registration_id)

    cond do
      not (scope && scope.user && registration.registrant_user_id == scope.user.id) ->
        raise Ecto.NoResultsError, queryable: Registration

      registration.status != :approved ->
        raise Ecto.NoResultsError, queryable: Registration

      not registration.training_activity.evaluation_required ->
        raise Ecto.NoResultsError, queryable: Registration

      true ->
        registration
    end
  end

  def get_submission_for_registration(registration_id) do
    EvaluationSubmission
    |> Repo.get_by(registration_id: registration_id)
    |> maybe_preload_submission()
  end

  def list_submission_map(registration_ids) when registration_ids == [], do: %{}

  def list_submission_map(registration_ids) do
    EvaluationSubmission
    |> where([submission], submission.registration_id in ^registration_ids)
    |> preload(^@submission_preloads)
    |> Repo.all()
    |> Map.new(&{&1.registration_id, &1})
  end

  def submit_evaluation(scope, registration_id, attrs) do
    registration = get_user_registration_for_evaluation!(scope, registration_id)

    evaluation_submission =
      Repo.get_by(EvaluationSubmission, registration_id: registration.id) ||
        %EvaluationSubmission{}

    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("registration_id", registration.id)
      |> Map.put("submitted_by_user_id", scope.user.id)
      |> Map.put("submitted_at", DateTime.utc_now(:second))

    evaluation_submission
    |> EvaluationSubmission.changeset(attrs)
    |> Repo.insert_or_update()
    |> preload_submission_result()
  end

  def list_training_completion(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    registrations =
      Registration
      |> where(
        [registration],
        registration.training_activity_id == ^training_activity.id and
          registration.status == :approved
      )
      |> preload(registrant_user: [:office, :role], training_activity: [])
      |> order_by([registration], asc: registration.inserted_at)
      |> Repo.all()

    registration_ids = Enum.map(registrations, & &1.id)

    submissions_by_registration_id = list_submission_map(registration_ids)

    sessions =
      AttendanceSession
      |> where([session], session.training_activity_id == ^training_activity.id)
      |> order_by([session], asc: session.session_date, asc: session.starts_at)
      |> Repo.all()

    session_ids = Enum.map(sessions, & &1.id)

    records_by_registration_id =
      if session_ids == [] or registration_ids == [] do
        %{}
      else
        AttendanceRecord
        |> where(
          [record],
          record.attendance_session_id in ^session_ids and
            record.registration_id in ^registration_ids
        )
        |> Repo.all()
        |> Enum.group_by(& &1.registration_id)
      end

    total_sessions_count = length(sessions)

    Enum.map(registrations, fn registration ->
      records = Map.get(records_by_registration_id, registration.id, [])

      attended_sessions_count =
        Enum.count(records, &(&1.status in @earned_attendance_statuses))

      attendance_percentage =
        if total_sessions_count == 0 do
          0
        else
          round(attended_sessions_count * 100 / total_sessions_count)
        end

      evaluation_submission = Map.get(submissions_by_registration_id, registration.id)

      %{
        registration: registration,
        evaluation_submission: evaluation_submission,
        total_sessions_count: total_sessions_count,
        attended_sessions_count: attended_sessions_count,
        attendance_percentage: attendance_percentage,
        completion_status:
          completion_status(
            training_activity,
            total_sessions_count,
            attendance_percentage,
            evaluation_submission
          )
      }
    end)
  end

  def completion_summary(entries) do
    base = %{
      completed: 0,
      pending_evaluation: 0,
      insufficient_attendance: 0,
      awaiting_attendance: 0
    }

    Enum.reduce(entries, base, fn entry, acc ->
      Map.update!(acc, entry.completion_status, &(&1 + 1))
    end)
  end

  def completion_status_label(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp completion_status(
         training_activity,
         total_sessions_count,
         attendance_percentage,
         evaluation_submission
       ) do
    cond do
      total_sessions_count == 0 ->
        :awaiting_attendance

      attendance_percentage < training_activity.minimum_attendance_percentage ->
        :insufficient_attendance

      training_activity.evaluation_required and is_nil(evaluation_submission) ->
        :pending_evaluation

      true ->
        :completed
    end
  end

  defp maybe_preload_submission(nil), do: nil
  defp maybe_preload_submission(submission), do: Repo.preload(submission, @submission_preloads)

  defp preload_submission_result({:ok, submission}) do
    {:ok, Repo.preload(submission, @submission_preloads)}
  end

  defp preload_submission_result(other), do: other

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp stringify_keys(attrs), do: attrs |> Enum.into(%{}) |> stringify_keys()
end
