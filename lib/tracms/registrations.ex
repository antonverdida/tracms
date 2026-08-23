defmodule Tracms.Registrations do
  @moduledoc """
  The Registrations context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Tracms.Accounts
  alias Tracms.Accounts.Scope
  alias Tracms.GoogleSheets
  alias Tracms.Registrations.ExternalRegistrationSubmission
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @preloads [
    training_activity: [:office, :division],
    registrant_user: [:office, :role],
    reviewer_user: []
  ]
  @external_preloads [
    training_activity: [:office, :division],
    matched_user: [:office, :role],
    imported_registration: [registrant_user: [:office, :role]],
    reviewer_user: []
  ]
  @bulk_import_header_map %{
    "full_name" => "full_name",
    "name" => "full_name",
    "participant_name" => "full_name",
    "email" => "email",
    "email_address" => "email",
    "deped_email" => "email",
    "employee_number" => "employee_number",
    "employee_no" => "employee_number",
    "office_name" => "office_name",
    "office" => "office_name",
    "school" => "office_name",
    "school_or_office" => "office_name",
    "source_reference" => "source_reference",
    "reference" => "source_reference",
    "response_id" => "source_reference",
    "special_requirements" => "special_requirements",
    "notes" => "special_requirements"
  }
  @bulk_import_required_headers ~w(full_name email)

  def list_open_training_activities(scope) do
    if scope && scope.user do
      training_ids = registered_training_ids(scope)

      TrainingActivity
      |> where([training], training.status == :published)
      |> where(
        [training],
        is_nil(training.registration_opens_on) or
          training.registration_opens_on <= ^Date.utc_today()
      )
      |> where(
        [training],
        is_nil(training.registration_deadline) or
          training.registration_deadline >= ^DateTime.utc_now(:second)
      )
      |> where([training], training.id not in ^training_ids)
      |> preload([:office, :division])
      |> order_by([training], asc: training.starts_on, asc: training.title)
      |> Repo.all()
    else
      []
    end
  end

  def get_participant_training_activity!(scope, training_id) do
    {:ok, user_id} = ensure_authenticated_scope(scope)

    training_activity =
      TrainingActivity
      |> preload([:office, :division])
      |> Repo.get!(training_id)

    registration =
      Registration
      |> where(
        [registration],
        registration.training_activity_id == ^training_activity.id and
          registration.registrant_user_id == ^user_id
      )
      |> preload(^@preloads)
      |> Repo.one()

    cond do
      registration ->
        {training_activity, registration}

      training_activity.status == :published ->
        {training_activity, nil}

      true ->
        raise Ecto.NoResultsError, queryable: TrainingActivity
    end
  end

  def active_registration_count(training_id) do
    from(registration in Registration,
      where:
        registration.training_activity_id == ^training_id and
          registration.status in [:submitted, :approved, :waitlisted],
      select: count(registration.id)
    )
    |> Repo.one()
  end

  def list_user_registrations(scope) do
    if scope && scope.user do
      Registration
      |> where([registration], registration.registrant_user_id == ^scope.user.id)
      |> preload(^@preloads)
      |> order_by([registration], desc: registration.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_manageable_registrations(scope) do
    if Scope.training_manager?(scope) do
      Registration
      |> join(:inner, [registration], training in assoc(registration, :training_activity))
      |> scope_manageable_registrations(scope)
      |> preload(^@preloads)
      |> order_by([registration, _training], desc: registration.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_manageable_registrations(scope, filters) when is_map(filters) do
    scope
    |> list_manageable_registrations()
    |> filter_loaded_manageable_registrations(filters)
  end

  def list_training_registrations(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    Registration
    |> where([registration], registration.training_activity_id == ^training_activity.id)
    |> preload(^@preloads)
    |> order_by([registration], asc: registration.inserted_at)
    |> Repo.all()
  end

  def list_external_registration_submissions(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    ExternalRegistrationSubmission
    |> where([submission], submission.training_activity_id == ^training_activity.id)
    |> preload(^@external_preloads)
    |> order_by([submission], asc: submission.inserted_at)
    |> Repo.all()
  end

  def change_external_registration_submission(
        %ExternalRegistrationSubmission{} = submission,
        attrs \\ %{}
      ) do
    ExternalRegistrationSubmission.changeset(submission, attrs)
  end

  def bulk_import_external_registration_submissions(scope, training_id, attrs) do
    with true <- Scope.training_manager?(scope),
         %TrainingActivity{} = training_activity <-
           manageable_training_for_external(scope, training_id),
         true <- external_collection_enabled?(training_activity),
         {:ok, %{headers: headers, rows: rows}} <-
           parse_bulk_import_table(attrs["tabular_data"] || attrs[:tabular_data]) do
      batch_reference =
        normalize_optional_string(attrs["batch_reference"] || attrs[:batch_reference])

      {:ok,
       stage_external_submission_rows(
         scope,
         training_activity,
         headers,
         rows,
         batch_reference,
         2
       )}
    else
      false -> {:error, :external_collection_not_enabled}
      nil -> {:error, :training_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def sync_external_registration_submissions_from_google_sheet(scope, training_id) do
    with true <- Scope.training_manager?(scope),
         %TrainingActivity{} = training_activity <-
           manageable_training_for_external(scope, training_id),
         true <- external_collection_enabled?(training_activity),
         {:ok, sheet_id, sheet_range} <- google_sheet_sync_config(training_activity),
         {:ok, %{headers: headers, rows: rows}} <-
           GoogleSheets.fetch_values(sheet_id, sheet_range) do
      result =
        stage_external_submission_rows(
          scope,
          training_activity,
          headers,
          rows,
          "Google Sheets sync #{Date.utc_today()}",
          2
        )

      update_google_sheet_last_synced_at(training_activity)

      {:ok, result}
    else
      false -> {:error, :external_collection_not_enabled}
      nil -> {:error, :training_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_user_registration_for_training(scope, training_id) do
    if scope && scope.user do
      Registration
      |> Repo.get_by(training_activity_id: training_id, registrant_user_id: scope.user.id)
      |> maybe_preload_registration()
    end
  end

  def register_user_for_training(scope, training_id, attrs \\ %{}) do
    with {:ok, user_id} <- ensure_authenticated_scope(scope),
         %TrainingActivity{} = training_activity <- Repo.get(TrainingActivity, training_id),
         :ok <- ensure_training_open(training_activity),
         :ok <- ensure_capacity_available(training_activity),
         nil <- get_user_registration_for_training(scope, training_id) do
      %Registration{}
      |> Registration.changeset(%{
        training_activity_id: training_id,
        registrant_user_id: user_id,
        submitted_at: DateTime.utc_now(:second),
        special_requirements: attrs["special_requirements"] || attrs[:special_requirements]
      })
      |> Repo.insert()
      |> preload_result()
    else
      {:error, :unauthorized} -> {:error, :unauthorized}
      nil -> {:error, :training_not_found}
      {:error, reason} -> {:error, reason}
      %Registration{} -> {:error, :already_registered}
    end
  end

  def create_manual_registrations(scope, training_id, participant_names) do
    names = normalize_manual_participant_names(participant_names)

    with true <- Scope.training_manager?(scope),
         %TrainingActivity{} = training_activity <- Repo.get(TrainingActivity, training_id),
         :ok <- ensure_manual_registration_allowed(training_activity),
         true <- names != [] do
      Repo.transaction(fn ->
        Enum.reduce_while(names, [], fn name, registrations ->
          with :ok <- ensure_capacity_available(training_activity),
               {:ok, registration} <-
                 %Registration{}
                 |> Registration.changeset(%{
                   training_activity_id: training_activity.id,
                   manual_participant_name: name,
                   status: :approved,
                   submitted_at: DateTime.utc_now(:second)
                 })
                 |> Repo.insert()
                 |> preload_result() do
            {:cont, [registration | registrations]}
          else
            {:error, reason} -> Repo.rollback(reason)
          end
        end)
      end)
      |> case do
        {:ok, registrations} -> {:ok, Enum.reverse(registrations)}
        {:error, reason} -> {:error, reason}
      end
    else
      false when names == [] -> {:error, :no_participant_names}
      false -> {:error, :unauthorized}
      nil -> {:error, :training_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def participant_name(%Registration{registrant_user: %{full_name: full_name, email: email}}) do
    full_name || email
  end

  def participant_name(%Registration{manual_participant_name: name}),
    do: name || "Guest Participant"

  def participant_email(%Registration{registrant_user: %{email: email}}), do: email
  def participant_email(%Registration{manual_participant_email: email}), do: email

  def participant_organization(%Registration{registrant_user: %{office: %{name: name}}}), do: name
  def participant_organization(_registration), do: "Not assigned"

  def withdraw_registration(scope, %Registration{} = registration) do
    if scope && scope.user && registration.registrant_user_id == scope.user.id &&
         registration.status in [:submitted, :approved, :waitlisted] do
      registration
      |> Registration.changeset(%{
        status: :withdrawn,
        reviewed_at: DateTime.utc_now(:second)
      })
      |> Repo.update()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def review_registration(scope, %Registration{} = registration, status, notes \\ nil) do
    with true <- Scope.training_manager?(scope),
         true <- manageable_registration?(scope, registration),
         true <- status in [:approved, :rejected, :waitlisted] do
      registration
      |> Registration.changeset(%{
        status: status,
        review_notes: notes,
        reviewed_at: DateTime.utc_now(:second),
        reviewer_user_id: scope.user.id
      })
      |> Repo.update()
      |> preload_result()
    else
      false -> {:error, :unauthorized}
    end
  end

  def change_manager_registration(%Registration{} = registration, attrs \\ %{}) do
    Registration.changeset(registration, attrs)
  end

  def update_registration(scope, %Registration{} = registration, attrs) do
    registration = maybe_preload_registration(registration)

    with true <- Scope.training_manager?(scope),
         true <- manageable_registration?(scope, registration),
         {:ok, attrs} <- normalize_manager_registration_attrs(scope, attrs) do
      registration
      |> Registration.changeset(attrs)
      |> Repo.update()
      |> preload_result()
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def cancel_registration(scope, %Registration{} = registration, notes \\ nil) do
    registration = maybe_preload_registration(registration)

    if Scope.training_manager?(scope) and manageable_registration?(scope, registration) do
      registration
      |> Registration.changeset(%{
        status: :withdrawn,
        review_notes: normalize_optional_string(notes) || registration.review_notes,
        reviewed_at: DateTime.utc_now(:second),
        reviewer_user_id: scope.user.id
      })
      |> Repo.update()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def create_external_registration_submission(scope, training_id, attrs) do
    with true <- Scope.training_manager?(scope),
         %TrainingActivity{} = training_activity <-
           manageable_training_for_external(scope, training_id),
         true <- external_collection_enabled?(training_activity) do
      attrs = normalize_external_submission_attrs(attrs)

      matched_user =
        case attrs["email"] do
          email when is_binary(email) -> Accounts.get_user_by_email(email)
          _ -> nil
        end

      %ExternalRegistrationSubmission{}
      |> ExternalRegistrationSubmission.changeset(
        attrs
        |> Map.put("training_activity_id", training_activity.id)
        |> Map.put("matched_user_id", matched_user && matched_user.id)
        |> Map.put("status", external_submission_status(matched_user))
        |> Map.put("submitted_at", DateTime.utc_now(:second))
      )
      |> Repo.insert()
      |> preload_external_result()
    else
      false -> {:error, :external_collection_not_enabled}
      nil -> {:error, :training_not_found}
    end
  end

  def import_external_registration_submission(
        scope,
        %ExternalRegistrationSubmission{} = submission
      ) do
    submission = maybe_preload_external_submission(submission)

    with true <- Scope.training_manager?(scope),
         true <- manageable_external_submission?(scope, submission),
         true <- submission.status in [:pending_review, :needs_account],
         %TrainingActivity{} = training_activity <- submission.training_activity,
         %{} = matched_user <-
           submission.matched_user || Accounts.get_user_by_email(submission.email) do
      registration_note =
        if ensure_capacity_available(training_activity) == :ok do
          nil
        else
          "Imported from external registration intake after capacity was reached."
        end

      Multi.new()
      |> Multi.run(:registration, fn repo, _changes ->
        case repo.get_by(Registration,
               training_activity_id: training_activity.id,
               registrant_user_id: matched_user.id
             ) do
          nil ->
            %Registration{}
            |> Registration.changeset(%{
              training_activity_id: training_activity.id,
              registrant_user_id: matched_user.id,
              status: if(registration_note, do: :waitlisted, else: :submitted),
              review_notes: registration_note,
              special_requirements: submission.special_requirements,
              submitted_at: submission.submitted_at
            })
            |> repo.insert()

          %Registration{} = registration ->
            {:ok, registration}
        end
      end)
      |> Multi.update(:submission, fn %{registration: registration} ->
        submission
        |> ExternalRegistrationSubmission.changeset(%{
          status: :imported,
          matched_user_id: matched_user.id,
          imported_registration_id: registration.id,
          reviewed_at: DateTime.utc_now(:second),
          reviewer_user_id: scope.user.id,
          review_notes: submission.review_notes || "Imported to the TRACMS registration workflow."
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{registration: registration}} -> preload_result({:ok, registration})
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    else
      false -> {:error, :unauthorized}
      nil -> {:error, :account_not_found}
    end
  end

  def reject_external_registration_submission(
        scope,
        %ExternalRegistrationSubmission{} = submission,
        notes \\ nil
      ) do
    submission = maybe_preload_external_submission(submission)

    with true <- Scope.training_manager?(scope),
         true <- manageable_external_submission?(scope, submission),
         true <- submission.status in [:pending_review, :needs_account] do
      submission
      |> ExternalRegistrationSubmission.changeset(%{
        status: :rejected,
        review_notes:
          notes || submission.review_notes || "Rejected during external intake review.",
        reviewed_at: DateTime.utc_now(:second),
        reviewer_user_id: scope.user.id
      })
      |> Repo.update()
      |> preload_external_result()
    else
      false -> {:error, :unauthorized}
    end
  end

  def format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp registered_training_ids(scope) do
    from(registration in Registration,
      where:
        registration.registrant_user_id == ^scope.user.id and registration.status != :withdrawn,
      select: registration.training_activity_id
    )
    |> Repo.all()
  end

  defp normalize_manual_participant_names(participant_names) do
    participant_names
    |> to_string()
    |> String.split(~r/\r?\n/, trim: true)
    |> Enum.map(&normalize_manual_participant_name/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
  end

  defp normalize_manual_participant_name(name) do
    name
    |> String.trim()
    |> String.replace(~r/^\d+\s*(?:[.)]|[-:])\s*/, "")
    |> String.trim()
  end

  defp ensure_authenticated_scope(%Scope{user: %{id: user_id}}), do: {:ok, user_id}
  defp ensure_authenticated_scope(_scope), do: {:error, :unauthorized}

  defp ensure_training_open(%TrainingActivity{
         status: :published,
         registration_opens_on: opens_on,
         registration_deadline: deadline
       }) do
    today = Date.utc_today()

    cond do
      not is_nil(opens_on) and Date.compare(opens_on, today) == :gt ->
        {:error, :registration_not_open}

      is_nil(deadline) or
          DateTime.compare(deadline, DateTime.utc_now(:second)) in [:gt, :eq] ->
        :ok

      true ->
        {:error, :registration_closed}
    end
  end

  defp ensure_training_open(%TrainingActivity{}), do: {:error, :not_published}

  # Managers can add late, walk-in, or certificate-reconciliation participants.
  defp ensure_manual_registration_allowed(%TrainingActivity{status: status})
       when status in [:published, :registration_closed, :in_progress, :completed],
       do: :ok

  defp ensure_manual_registration_allowed(%TrainingActivity{}),
    do: {:error, :manual_registration_not_allowed}

  defp ensure_capacity_available(%TrainingActivity{max_capacity: nil}), do: :ok

  defp ensure_capacity_available(%TrainingActivity{id: training_id, max_capacity: max_capacity}) do
    active_count =
      from(registration in Registration,
        where:
          registration.training_activity_id == ^training_id and
            registration.status in [:submitted, :approved, :waitlisted],
        select: count(registration.id)
      )
      |> Repo.one()

    if active_count < max_capacity do
      :ok
    else
      {:error, :capacity_reached}
    end
  end

  defp manageable_registration?(scope, registration) do
    training_activity =
      if Ecto.assoc_loaded?(registration.training_activity) do
        registration.training_activity
      else
        Repo.get(TrainingActivity, registration.training_activity_id)
      end

    cond do
      Scope.regional_admin?(scope) ->
        true

      Scope.division_admin?(scope) ->
        scope.division_id && training_activity.division_id == scope.division_id

      Scope.coordinator?(scope) ->
        scope.office_id && training_activity.office_id == scope.office_id

      true ->
        false
    end
  end

  defp manageable_external_submission?(scope, submission) do
    training_activity =
      if Ecto.assoc_loaded?(submission.training_activity) do
        submission.training_activity
      else
        Repo.get(TrainingActivity, submission.training_activity_id)
      end

    training_activity && manageable_training?(scope, training_activity)
  end

  defp manageable_training_for_external(scope, training_id) do
    training_activity = Repo.get(TrainingActivity, training_id)

    if training_activity && manageable_training?(scope, training_activity) do
      Repo.preload(training_activity, [:office, :division])
    end
  end

  defp manageable_training?(scope, training_activity) do
    cond do
      Scope.regional_admin?(scope) ->
        true

      Scope.division_admin?(scope) ->
        scope.division_id && training_activity.division_id == scope.division_id

      Scope.coordinator?(scope) ->
        scope.office_id && training_activity.office_id == scope.office_id

      true ->
        false
    end
  end

  defp external_collection_enabled?(training_activity),
    do:
      is_binary(training_activity.registration_form_url) and
        training_activity.registration_form_url != ""

  defp external_submission_status(nil), do: :needs_account
  defp external_submission_status(_user), do: :pending_review

  defp google_sheet_sync_config(training_activity) do
    sheet_id = normalize_optional_string(training_activity.registration_sheet_id)
    sheet_range = normalize_optional_string(training_activity.registration_sheet_range)

    cond do
      is_nil(sheet_id) or is_nil(sheet_range) ->
        {:error, :google_sheet_sync_not_configured}

      true ->
        {:ok, sheet_id, sheet_range}
    end
  end

  defp parse_bulk_import_table(nil), do: {:error, :empty_import_data}
  defp parse_bulk_import_table(""), do: {:error, :empty_import_data}

  defp parse_bulk_import_table(raw_data) when is_binary(raw_data) do
    lines =
      raw_data
      |> String.split(~r/\r\n|\n|\r/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    with [_header_line | _data_lines] = lines <- lines,
         delimiter <- detect_bulk_import_delimiter(hd(lines)),
         [header_row | data_rows] <- Enum.map(lines, &parse_bulk_import_row(&1, delimiter)),
         {:ok, headers} <- normalize_bulk_import_headers(header_row),
         false <- data_rows == [] do
      {:ok, %{headers: headers, rows: data_rows}}
    else
      [] -> {:error, :empty_import_data}
      true -> {:error, :no_import_rows}
      {:error, reason} -> {:error, reason}
    end
  end

  defp detect_bulk_import_delimiter(header_line) do
    if String.contains?(header_line, "\t"), do: "\t", else: ","
  end

  defp parse_bulk_import_row(line, delimiter) do
    line
    |> String.split(delimiter)
    |> Enum.map(&normalize_bulk_import_cell/1)
  end

  defp normalize_bulk_import_cell(cell) do
    cell
    |> String.trim()
    |> String.trim("\"")
    |> String.trim()
  end

  defp normalize_bulk_import_headers(header_row) do
    headers =
      Enum.map(header_row, fn header ->
        header
        |> String.downcase()
        |> String.trim()
        |> String.replace(~r/[^a-z0-9]+/, "_")
        |> String.trim("_")
        |> then(&Map.get(@bulk_import_header_map, &1))
      end)

    missing_headers =
      @bulk_import_required_headers
      |> Enum.reject(&(&1 in headers))

    if missing_headers == [] do
      {:ok, headers}
    else
      {:error, {:missing_import_headers, missing_headers}}
    end
  end

  defp build_bulk_import_attrs(row, headers) do
    headers
    |> Enum.zip(pad_bulk_import_row(row, length(headers)))
    |> Enum.reduce(%{}, fn
      {nil, _value}, acc ->
        acc

      {field, value}, acc ->
        Map.put(acc, field, value)
    end)
  end

  defp pad_bulk_import_row(row, expected_length) do
    row ++ List.duplicate(nil, max(expected_length - length(row), 0))
  end

  defp maybe_put_batch_reference(attrs, _row_number, nil), do: attrs

  defp maybe_put_batch_reference(attrs, row_number, batch_reference) do
    Map.put_new(attrs, "source_reference", "#{batch_reference} row #{row_number}")
  end

  defp finalize_bulk_import_result(result) do
    %{
      created: Enum.reverse(result.created),
      created_count: length(result.created),
      skipped_rows: Enum.reverse(result.skipped),
      skipped_count: length(result.skipped),
      errors: Enum.reverse(result.errors),
      error_count: length(result.errors)
    }
  end

  defp bulk_import_error(row_number, message), do: %{row: row_number, message: message}

  defp bulk_import_error_message(:training_not_found), do: "training record is not available"

  defp bulk_import_error_message(:external_collection_not_enabled),
    do: "external collection is not enabled"

  defp bulk_import_error_message(:empty_import_data), do: "no import data was provided"

  defp bulk_import_error_message(:no_import_rows),
    do: "no data rows were found after the header row"

  defp bulk_import_error_message({:missing_import_headers, headers}) do
    "missing required headers: #{Enum.join(headers, ", ")}"
  end

  defp bulk_import_error_message(reason) when is_atom(reason),
    do: reason |> Atom.to_string() |> String.replace("_", " ")

  defp bulk_import_error_message(_reason), do: "unable to import this row"

  defp changeset_error_message(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _opts}} ->
      "#{field |> Atom.to_string() |> String.replace("_", " ")} #{message}"
    end)
    |> Enum.join(", ")
  end

  defp stage_external_submission_rows(
         scope,
         training_activity,
         headers,
         rows,
         batch_reference,
         row_offset
       ) do
    rows
    |> Enum.with_index(row_offset)
    |> Enum.reduce(%{created: [], errors: [], skipped: []}, fn {row, row_number}, acc ->
      submission_attrs =
        row
        |> build_bulk_import_attrs(headers)
        |> maybe_put_batch_reference(row_number, batch_reference)

      cond do
        duplicate_external_submission?(training_activity.id, submission_attrs) ->
          %{acc | skipped: [row_number | acc.skipped]}

        true ->
          case create_external_registration_submission(
                 scope,
                 training_activity.id,
                 submission_attrs
               ) do
            {:ok, submission} ->
              %{acc | created: [submission | acc.created]}

            {:error, %Ecto.Changeset{} = changeset} ->
              %{
                acc
                | errors: [
                    bulk_import_error(row_number, changeset_error_message(changeset)) | acc.errors
                  ]
              }

            {:error, reason} ->
              %{
                acc
                | errors: [
                    bulk_import_error(row_number, bulk_import_error_message(reason)) | acc.errors
                  ]
              }
          end
      end
    end)
    |> finalize_bulk_import_result()
  end

  defp duplicate_external_submission?(training_activity_id, attrs) do
    source_reference = normalize_optional_string(attrs["source_reference"])
    email = normalize_optional_string(attrs["email"])
    full_name = normalize_optional_string(attrs["full_name"])

    query =
      cond do
        source_reference ->
          from(submission in ExternalRegistrationSubmission,
            where:
              submission.training_activity_id == ^training_activity_id and
                submission.source_reference == ^source_reference
          )

        email && full_name ->
          from(submission in ExternalRegistrationSubmission,
            where:
              submission.training_activity_id == ^training_activity_id and
                submission.email == ^email and
                submission.full_name == ^full_name
          )

        true ->
          nil
      end

    if query, do: Repo.exists?(query), else: false
  end

  defp update_google_sheet_last_synced_at(training_activity) do
    training_activity
    |> Ecto.Changeset.change(registration_sheet_last_synced_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  defp normalize_external_submission_attrs(attrs) do
    attrs
    |> Enum.into(%{})
    |> Map.update("full_name", nil, &normalize_optional_string/1)
    |> Map.update("email", nil, &normalize_optional_string/1)
    |> Map.update("employee_number", nil, &normalize_optional_string/1)
    |> Map.update("office_name", nil, &normalize_optional_string/1)
    |> Map.update("source_reference", nil, &normalize_optional_string/1)
    |> Map.update("special_requirements", nil, &normalize_optional_string/1)
    |> Map.update("review_notes", nil, &normalize_optional_string/1)
  end

  defp normalize_optional_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_optional_string(value), do: value

  defp maybe_preload_registration(nil), do: nil
  defp maybe_preload_registration(registration), do: Repo.preload(registration, @preloads)

  defp maybe_preload_external_submission(submission),
    do: Repo.preload(submission, @external_preloads)

  defp preload_result({:ok, registration}), do: {:ok, Repo.preload(registration, @preloads)}
  defp preload_result(other), do: other

  defp preload_external_result({:ok, submission}) do
    {:ok, Repo.preload(submission, @external_preloads)}
  end

  defp preload_external_result(other), do: other

  defp normalize_manager_registration_attrs(scope, attrs) do
    status = attrs["status"] || attrs[:status]
    training_activity_id = attrs["training_activity_id"] || attrs[:training_activity_id]

    cond do
      status not in [nil, "", :submitted, "submitted", :withdrawn, "withdrawn"] ->
        {:error, :invalid_status}

      is_binary(training_activity_id) and training_activity_id != "" and
          is_nil(manageable_training_for_external(scope, training_activity_id)) ->
        {:error, :training_not_found}

      true ->
        normalized_attrs =
          attrs
          |> Map.new(fn {key, value} -> {to_string(key), value} end)
          |> Map.take(["training_activity_id", "special_requirements", "review_notes"])
          |> maybe_put_manager_status(status, scope)

        {:ok, normalized_attrs}
    end
  end

  defp maybe_put_manager_status(attrs, nil, _scope), do: attrs
  defp maybe_put_manager_status(attrs, "", _scope), do: attrs

  defp maybe_put_manager_status(attrs, status, scope) when status in [:submitted, "submitted"] do
    attrs
    |> Map.put("status", :submitted)
    |> Map.put("reviewed_at", DateTime.utc_now(:second))
    |> Map.put("reviewer_user_id", scope.user.id)
  end

  defp maybe_put_manager_status(attrs, status, scope) when status in [:withdrawn, "withdrawn"] do
    attrs
    |> Map.put("status", :withdrawn)
    |> Map.put("reviewed_at", DateTime.utc_now(:second))
    |> Map.put("reviewer_user_id", scope.user.id)
  end

  defp filter_loaded_manageable_registrations(registrations, filters) do
    registrations
    |> filter_loaded_by_search(filters["search"] || filters[:search])
    |> filter_loaded_by_training(filters["training_id"] || filters[:training_id])
    |> filter_loaded_by_status_group(filters["status"] || filters[:status])
  end

  defp filter_loaded_by_search(registrations, nil), do: registrations
  defp filter_loaded_by_search(registrations, ""), do: registrations

  defp filter_loaded_by_search(registrations, search) when is_binary(search) do
    search = search |> String.trim() |> String.downcase()

    Enum.filter(registrations, fn registration ->
      searchable_fields = [
        participant_name(registration),
        participant_email(registration),
        registration.registrant_user && registration.registrant_user.employee_number,
        registration.training_activity.title,
        participant_organization(registration),
        registration.special_requirements,
        registration.review_notes
      ]

      Enum.any?(searchable_fields, fn value ->
        value &&
          value
          |> to_string()
          |> String.downcase()
          |> String.contains?(search)
      end)
    end)
  end

  defp filter_loaded_by_training(registrations, nil), do: registrations
  defp filter_loaded_by_training(registrations, ""), do: registrations

  defp filter_loaded_by_training(registrations, training_id) when is_binary(training_id) do
    Enum.filter(registrations, &(&1.training_activity_id == training_id))
  end

  defp filter_loaded_by_status_group(registrations, nil), do: registrations
  defp filter_loaded_by_status_group(registrations, ""), do: registrations

  defp filter_loaded_by_status_group(registrations, status)
       when status in ["registered", :registered] do
    Enum.filter(registrations, &(&1.status in [:submitted, :approved, :waitlisted]))
  end

  defp filter_loaded_by_status_group(registrations, status)
       when status in ["cancelled", :cancelled] do
    Enum.filter(registrations, &(&1.status in [:rejected, :withdrawn]))
  end

  defp filter_loaded_by_status_group(registrations, _status), do: registrations

  defp scope_manageable_registrations(query, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        query

      Scope.division_admin?(scope) and scope.division_id ->
        where(query, [_registration, training], training.division_id == ^scope.division_id)

      Scope.coordinator?(scope) and scope.office_id ->
        where(query, [_registration, training], training.office_id == ^scope.office_id)

      true ->
        where(query, [_registration, _training], false)
    end
  end
end
