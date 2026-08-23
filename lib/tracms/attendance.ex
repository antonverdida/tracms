defmodule Tracms.Attendance do
  @moduledoc """
  The Attendance context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Attendance.{AttendanceRecord, AttendanceSession}
  alias Tracms.GoogleSheets
  alias Tracms.Registrations
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @session_preloads [
    training_activity: [:office, :division],
    opened_by_user: [],
    closed_by_user: []
  ]

  @record_preloads [
    registration: [registrant_user: [:office, :role], training_activity: []],
    marked_by_user: []
  ]
  @attendance_header_map %{
    "email" => "email",
    "email_address" => "email",
    "deped_email" => "email",
    "status" => "status",
    "attendance_status" => "status",
    "remarks" => "notes",
    "notes" => "notes"
  }
  @attendance_required_headers ~w(email)

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

  def get_training_attendance(scope, training_id, requested_session_id \\ nil) do
    with {:ok, training_activity} <- fetch_manageable_training(scope, training_id) do
      attendance_sessions = list_sessions(scope, training_activity.id)
      attendance_session = select_management_session(attendance_sessions, requested_session_id)

      entries =
        scope
        |> list_approved_registrations(training_activity.id)
        |> build_management_entries(attendance_session)

      {:ok,
       %{
         training_activity: training_activity,
         attendance_session: attendance_session,
         attendance_sessions: attendance_sessions,
         entries: entries
       }}
    end
  end

  def filter_training_attendance_entries(entries, search) do
    case normalize_optional_string(search) do
      nil ->
        entries

      search_term ->
        normalized_search = String.downcase(search_term)

        Enum.filter(entries, fn entry ->
          searchable_attendance_text(entry)
          |> String.downcase()
          |> String.contains?(normalized_search)
        end)
    end
  end

  def save_training_attendance(scope, training_id, entries_params, session_id \\ nil) do
    with {:ok, training_activity} <- fetch_manageable_training(scope, training_id),
         {:ok, normalized_entries} <- normalize_management_entries(entries_params),
         :ok <- ensure_attendance_selected(normalized_entries),
         {:ok, attendance_session} <-
           management_session_for_save(scope, training_activity, session_id) do
      save_management_entries(scope, attendance_session, normalized_entries)
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

  def sync_session_attendance_from_google_sheet(scope, session_id) do
    session = get_session!(scope, session_id)

    with :ok <- ensure_session_open(session),
         {:ok, sheet_id, sheet_range} <-
           attendance_google_sheet_sync_config(session.training_activity),
         {:ok, %{headers: headers, rows: rows}} <-
           GoogleSheets.fetch_values(sheet_id, sheet_range),
         {:ok, normalized_headers} <- normalize_attendance_sync_headers(headers) do
      registrations_by_email =
        list_approved_registrations(scope, session.training_activity_id)
        |> Enum.reduce(%{}, fn registration, registrations_by_email ->
          case Registrations.participant_email(registration) |> normalize_email() do
            nil -> registrations_by_email
            email -> Map.put(registrations_by_email, email, registration)
          end
        end)

      result =
        rows
        |> Enum.with_index(2)
        |> Enum.reduce(
          %{updated: [], skipped: [], errors: [], seen_emails: MapSet.new()},
          fn {row, row_number}, acc ->
            row_attrs = build_attendance_sync_attrs(row, normalized_headers)
            email = normalize_email(row_attrs["email"])

            cond do
              is_nil(email) ->
                %{
                  acc
                  | errors: [attendance_sync_error(row_number, "email is required") | acc.errors]
                }

              MapSet.member?(acc.seen_emails, email) ->
                %{
                  acc
                  | skipped: [row_number | acc.skipped],
                    seen_emails: MapSet.put(acc.seen_emails, email)
                }

              true ->
                status = attendance_status_from_sheet(row_attrs["status"])
                notes = normalize_optional_string(row_attrs["notes"])

                sync_attendance_row(
                  acc,
                  scope,
                  session,
                  row_number,
                  email,
                  status,
                  notes,
                  registrations_by_email
                )
            end
          end
        )
        |> finalize_attendance_sync_result()

      update_attendance_google_sheet_last_synced_at(session.training_activity)

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
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

  def manual_status(nil), do: nil
  def manual_status(%AttendanceRecord{status: :absent}), do: :absent
  def manual_status(%AttendanceRecord{}), do: :present

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

  defp build_management_entries(registrations, attendance_session) do
    records_by_registration_id =
      case attendance_session do
        %AttendanceSession{} = session ->
          AttendanceRecord
          |> where([record], record.attendance_session_id == ^session.id)
          |> preload(^@record_preloads)
          |> Repo.all()
          |> Map.new(&{&1.registration_id, &1})

        nil ->
          %{}
      end

    Enum.map(registrations, fn registration ->
      %{registration: registration, record: Map.get(records_by_registration_id, registration.id)}
    end)
  end

  defp searchable_attendance_text(entry) do
    [
      Registrations.participant_name(entry.registration),
      Registrations.participant_email(entry.registration),
      Registrations.participant_organization(entry.registration),
      entry.registration.training_activity.title
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp normalize_management_entries(entries_params) when is_list(entries_params) do
    normalized_entries =
      Enum.map(entries_params, fn params ->
        %{
          registration_id: Map.get(params, "registration_id"),
          status:
            params
            |> Map.get("status")
            |> normalize_optional_string()
            |> normalize_management_status(),
          notes: normalize_optional_string(Map.get(params, "notes"))
        }
      end)

    {:ok, normalized_entries}
  end

  defp normalize_management_entries(entries_params) when is_map(entries_params) do
    entries_params
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map(fn {_key, value} -> value end)
    |> normalize_management_entries()
  end

  defp normalize_management_entries(_entries_params), do: {:ok, []}

  defp normalize_management_status("present"), do: :present
  defp normalize_management_status("absent"), do: :absent
  defp normalize_management_status(_status), do: nil

  defp ensure_attendance_selected(entries) do
    if Enum.any?(entries, &(&1.status in [:present, :absent])) do
      :ok
    else
      {:error, :no_attendance_selected}
    end
  end

  defp ensure_management_session(scope, %TrainingActivity{} = training_activity) do
    session =
      scope
      |> list_sessions(training_activity.id)
      |> pick_management_session()

    case session do
      %AttendanceSession{status: :open} = attendance_session ->
        {:ok, attendance_session}

      %AttendanceSession{status: :draft} = attendance_session ->
        open_session(scope, attendance_session)

      %AttendanceSession{status: :closed} = attendance_session ->
        reopen_session(scope, attendance_session)

      nil ->
        with {:ok, attendance_session} <-
               create_session(
                 scope,
                 training_activity.id,
                 default_management_session_attrs(training_activity)
               ),
             {:ok, open_session} <- open_session(scope, attendance_session) do
          {:ok, open_session}
        end
    end
  end

  defp management_session_for_save(scope, training_activity, nil) do
    ensure_management_session(scope, training_activity)
  end

  defp management_session_for_save(scope, training_activity, session_id) do
    session =
      scope
      |> list_sessions(training_activity.id)
      |> Enum.find(&(&1.id == session_id))

    case session do
      %AttendanceSession{status: :open} = attendance_session -> {:ok, attendance_session}
      %AttendanceSession{} -> {:error, :session_not_open}
      nil -> {:error, :attendance_session_not_found}
    end
  end

  defp reopen_session(scope, %AttendanceSession{} = attendance_session) do
    session = get_session!(scope, attendance_session.id)

    session
    |> AttendanceSession.changeset(%{status: :open, opened_by_user_id: scope.user.id})
    |> Repo.update()
    |> preload_session_result()
  end

  defp default_management_session_attrs(training_activity) do
    %{
      "name" => "General Attendance",
      "session_date" => training_activity.starts_on || Date.utc_today(),
      "starts_at" => ~T[08:00:00],
      "ends_at" => ~T[17:00:00]
    }
  end

  defp save_management_entries(scope, attendance_session, normalized_entries) do
    normalized_entries
    |> Enum.filter(&(&1.status in [:present, :absent]))
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, records} ->
      case mark_attendance(scope, attendance_session.id, entry.registration_id, %{
             status: entry.status,
             notes: entry.notes
           }) do
        {:ok, attendance_record} ->
          {:cont, {:ok, [attendance_record | records]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, records} ->
        {:ok,
         %{
           attendance_session: attendance_session,
           attendance_records: Enum.reverse(records),
           saved_count: length(records)
         }}

      other ->
        other
    end
  end

  defp pick_management_session([]), do: nil

  defp pick_management_session(attendance_sessions) do
    reversed_sessions = Enum.reverse(attendance_sessions)

    Enum.find(reversed_sessions, &(&1.status == :open)) ||
      Enum.find(reversed_sessions, &(&1.status == :draft)) ||
      List.last(attendance_sessions)
  end

  defp select_management_session(attendance_sessions, requested_session_id) do
    Enum.find(attendance_sessions, &(&1.id == requested_session_id)) ||
      pick_management_session(attendance_sessions)
  end

  defp fetch_approved_registration(scope, training_id, registration_id) do
    case Enum.find(list_approved_registrations(scope, training_id), &(&1.id == registration_id)) do
      %Registration{} = registration -> {:ok, registration}
      nil -> {:error, :registration_not_approved}
    end
  end

  defp attendance_google_sheet_sync_config(%TrainingActivity{} = training_activity) do
    sheet_id = normalize_optional_string(training_activity.attendance_sheet_id)
    sheet_range = normalize_optional_string(training_activity.attendance_sheet_range)

    cond do
      is_nil(sheet_id) or is_nil(sheet_range) ->
        {:error, :google_sheet_sync_not_configured}

      true ->
        {:ok, sheet_id, sheet_range}
    end
  end

  defp normalize_attendance_sync_headers(headers) do
    normalized_headers =
      Enum.map(headers, fn header ->
        header
        |> String.downcase()
        |> String.trim()
        |> String.replace(~r/[^a-z0-9]+/, "_")
        |> String.trim("_")
        |> then(&Map.get(@attendance_header_map, &1))
      end)

    missing_headers =
      @attendance_required_headers
      |> Enum.reject(&(&1 in normalized_headers))

    if missing_headers == [] do
      {:ok, normalized_headers}
    else
      {:error, {:missing_attendance_sync_headers, missing_headers}}
    end
  end

  defp build_attendance_sync_attrs(row, headers) do
    headers
    |> Enum.zip(pad_attendance_sync_row(row, length(headers)))
    |> Enum.reduce(%{}, fn
      {nil, _value}, acc ->
        acc

      {field, value}, acc ->
        Map.put(acc, field, normalize_optional_string(value))
    end)
  end

  defp pad_attendance_sync_row(row, expected_length) do
    row ++ List.duplicate(nil, max(expected_length - length(row), 0))
  end

  defp sync_attendance_row(
         acc,
         scope,
         session,
         row_number,
         email,
         status,
         notes,
         registrations_by_email
       ) do
    case {Map.get(registrations_by_email, email), status} do
      {nil, _status} ->
        %{
          acc
          | errors: [
              attendance_sync_error(row_number, "no approved registration matches #{email}")
              | acc.errors
            ],
            seen_emails: MapSet.put(acc.seen_emails, email)
        }

      {_registration, :invalid} ->
        %{
          acc
          | errors: [
              attendance_sync_error(
                row_number,
                "attendance status must be present, late, excused, or absent"
              )
              | acc.errors
            ],
            seen_emails: MapSet.put(acc.seen_emails, email)
        }

      {%Registration{} = registration, valid_status} ->
        case mark_attendance(scope, session.id, registration.id, %{
               status: valid_status,
               notes: notes
             }) do
          {:ok, attendance_record} ->
            %{
              acc
              | updated: [attendance_record | acc.updated],
                seen_emails: MapSet.put(acc.seen_emails, email)
            }

          {:error, %Ecto.Changeset{} = changeset} ->
            %{
              acc
              | errors: [
                  attendance_sync_error(row_number, changeset_error_message(changeset))
                  | acc.errors
                ],
                seen_emails: MapSet.put(acc.seen_emails, email)
            }

          {:error, :registration_not_approved} ->
            %{
              acc
              | errors: [
                  attendance_sync_error(row_number, "registration is not approved") | acc.errors
                ],
                seen_emails: MapSet.put(acc.seen_emails, email)
            }

          {:error, :session_not_open} ->
            %{
              acc
              | errors: [
                  attendance_sync_error(row_number, "attendance session is not open") | acc.errors
                ],
                seen_emails: MapSet.put(acc.seen_emails, email)
            }

          {:error, reason} ->
            %{
              acc
              | errors: [
                  attendance_sync_error(row_number, attendance_sync_error_message(reason))
                  | acc.errors
                ],
                seen_emails: MapSet.put(acc.seen_emails, email)
            }
        end
    end
  end

  defp attendance_status_from_sheet(nil), do: :present
  defp attendance_status_from_sheet(""), do: :present

  defp attendance_status_from_sheet(status) when is_binary(status) do
    case status |> String.trim() |> String.downcase() |> String.replace(~r/[^a-z]+/, "_") do
      "present" -> :present
      "late" -> :late
      "excused" -> :excused
      "absent" -> :absent
      _ -> :invalid
    end
  end

  defp update_attendance_google_sheet_last_synced_at(%TrainingActivity{} = training_activity) do
    training_activity
    |> Ecto.Changeset.change(attendance_sheet_last_synced_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  defp finalize_attendance_sync_result(result) do
    %{
      updated_records: Enum.reverse(result.updated),
      updated_count: length(result.updated),
      skipped_rows: Enum.reverse(result.skipped),
      skipped_count: length(result.skipped),
      errors: Enum.reverse(result.errors),
      error_count: length(result.errors)
    }
  end

  defp attendance_sync_error(row_number, message), do: %{row: row_number, message: message}

  defp attendance_sync_error_message({:missing_attendance_sync_headers, headers}) do
    "missing required headers: #{Enum.join(headers, ", ")}"
  end

  defp attendance_sync_error_message(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  defp attendance_sync_error_message(_reason), do: "unable to import this row"

  defp changeset_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _opts}} ->
      "#{field |> Atom.to_string() |> String.replace("_", " ")} #{message}"
    end)
    |> Enum.join(", ")
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

  defp normalize_optional_string(nil), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_optional_string(value), do: value |> to_string() |> normalize_optional_string()

  defp normalize_email(nil), do: nil

  defp normalize_email(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil -> nil
      email -> String.downcase(email)
    end
  end
end
