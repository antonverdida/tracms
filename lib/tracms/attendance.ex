defmodule Tracms.Attendance do
  @moduledoc """
  The Attendance context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Attendance.{AttendanceRecord, AttendanceSession}
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings

  @session_preloads [
    training_activity: [:office, :division],
    opened_by_user: [],
    closed_by_user: []
  ]

  @record_preloads [
    registration: [registrant_user: [:office, :role], training_activity: []],
    marked_by_user: []
  ]

  def list_sessions(scope, training_id) do
    with {:ok, training_activity} <- fetch_manageable_training(scope, training_id) do
      AttendanceSession
      |> where([session], session.training_activity_id == ^training_activity.id)
      |> preload(^@session_preloads)
      |> order_by([session],
        asc: session.session_date,
        asc: session.starts_at,
        asc: session.inserted_at
      )
      |> Repo.all()
    else
      _ -> []
    end
  end

  def get_session!(scope, session_id) do
    session =
      AttendanceSession
      |> preload(^@session_preloads)
      |> Repo.get!(session_id)

    {:ok, _training_activity} =
      fetch_manageable_training(scope, session.training_activity_id)

    session
  end

  def change_session(%AttendanceSession{} = attendance_session, attrs \\ %{}) do
    AttendanceSession.changeset(attendance_session, attrs)
  end

  def create_session(scope, training_id, attrs) do
    with {:ok, training_activity} <- fetch_manageable_training(scope, training_id) do
      attrs =
        attrs
        |> stringify_keys()
        |> Map.put("training_activity_id", training_activity.id)

      %AttendanceSession{}
      |> AttendanceSession.changeset(attrs)
      |> Repo.insert()
      |> preload_session_result()
    end
  end

  def open_session(scope, %AttendanceSession{} = attendance_session) do
    transition_session(scope, attendance_session, :open)
  end

  def close_session(scope, %AttendanceSession{} = attendance_session) do
    transition_session(scope, attendance_session, :closed)
  end

  def list_session_roster(scope, session_id) do
    session = get_session!(scope, session_id)
    registrations = list_approved_registrations(scope, session.training_activity_id)

    records_by_registration_id =
      AttendanceRecord
      |> where([record], record.attendance_session_id == ^session.id)
      |> preload(^@record_preloads)
      |> Repo.all()
      |> Map.new(&{&1.registration_id, &1})

    Enum.map(registrations, fn registration ->
      %{registration: registration, record: Map.get(records_by_registration_id, registration.id)}
    end)
  end

  def mark_attendance(scope, session_id, registration_id, attrs) do
    session = get_session!(scope, session_id)

    with :ok <- ensure_session_open(session),
         {:ok, registration} <-
           fetch_approved_registration(scope, session.training_activity_id, registration_id) do
      attendance_record =
        Repo.get_by(AttendanceRecord,
          attendance_session_id: session.id,
          registration_id: registration.id
        ) || %AttendanceRecord{}

      attrs =
        attrs
        |> stringify_keys()
        |> Map.put("attendance_session_id", session.id)
        |> Map.put("registration_id", registration.id)
        |> Map.put("marked_at", DateTime.utc_now(:second))
        |> Map.put("marked_by_user_id", scope.user.id)

      attendance_record
      |> AttendanceRecord.changeset(attrs)
      |> Repo.insert_or_update()
      |> preload_record_result()
    end
  end

  def roster_summary(entries) do
    base = %{present: 0, late: 0, excused: 0, absent: 0, unmarked: 0}

    Enum.reduce(entries, base, fn entry, acc ->
      key = if entry.record, do: entry.record.status, else: :unmarked
      Map.update!(acc, key, &(&1 + 1))
    end)
  end

  def format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp transition_session(scope, %AttendanceSession{} = attendance_session, target_status) do
    session = get_session!(scope, attendance_session.id)

    with :ok <- ensure_transition(session.status, target_status) do
      attrs =
        case target_status do
          :open ->
            %{status: :open, opened_by_user_id: scope.user.id}

          :closed ->
            %{status: :closed, closed_by_user_id: scope.user.id}
        end

      session
      |> AttendanceSession.changeset(attrs)
      |> Repo.update()
      |> preload_session_result()
    end
  end

  defp ensure_transition(:draft, :open), do: :ok
  defp ensure_transition(:open, :closed), do: :ok
  defp ensure_transition(_current_status, _target_status), do: {:error, :invalid_transition}

  defp ensure_session_open(%AttendanceSession{status: :open}), do: :ok
  defp ensure_session_open(_attendance_session), do: {:error, :session_not_open}

  defp fetch_manageable_training(scope, training_id) do
    if Scope.training_manager?(scope) do
      {:ok, Trainings.get_training_activity!(scope, training_id)}
    else
      {:error, :unauthorized}
    end
  end

  defp list_approved_registrations(scope, training_id) do
    if Scope.training_manager?(scope) do
      Registration
      |> where(
        [registration],
        registration.training_activity_id == ^training_id and registration.status == :approved
      )
      |> preload([:training_activity, registrant_user: [:office, :role]])
      |> order_by([registration], asc: registration.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  defp fetch_approved_registration(scope, training_id, registration_id) do
    case Enum.find(list_approved_registrations(scope, training_id), &(&1.id == registration_id)) do
      %Registration{} = registration -> {:ok, registration}
      nil -> {:error, :registration_not_approved}
    end
  end

  defp preload_session_result({:ok, attendance_session}) do
    {:ok, Repo.preload(attendance_session, @session_preloads)}
  end

  defp preload_session_result(other), do: other

  defp preload_record_result({:ok, attendance_record}) do
    {:ok, Repo.preload(attendance_record, @record_preloads)}
  end

  defp preload_record_result(other), do: other

  defp stringify_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp stringify_keys(attrs), do: attrs |> Enum.into(%{}) |> stringify_keys()
end
