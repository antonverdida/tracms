defmodule Tracms.SchemaHealth do
  @moduledoc """
  Checks critical TRACMS tables and columns for schema drift.
  """

  alias Ecto.Adapters.SQL
  alias Tracms.Repo

  @expected_tables %{
    "users" => ~w(
      id email hashed_password confirmed_at inserted_at updated_at full_name employee_number
      status approved_at role_id office_id notification_preferences
    ),
    "users_tokens" => ~w(id user_id token context sent_to inserted_at),
    "roles" => ~w(id key name scope inserted_at updated_at),
    "divisions" => ~w(id code name region inserted_at updated_at),
    "offices" => ~w(id code name level division_id inserted_at updated_at),
    "training_activities" => ~w(
      id title description category training_type organizer modality venue venue_address status
      registration_opens_on registration_deadline max_capacity starts_on ends_on total_hours
      start_time end_time resource_speaker objectives target_participants participant_qualification
      attendance_monitoring_method
      certificate_type certificate_layout_style certificate_accent_color
      certificate_header_title certificate_header_subtitle certificate_body_intro
      certificate_completion_statement certificate_signature_label
      certificate_issuing_office_label published_at minimum_attendance_percentage evaluation_required
      registration_form_id registration_form_url attendance_form_id attendance_form_url
      registration_sheet_id registration_sheet_range registration_sheet_last_synced_at
      attendance_sheet_id attendance_sheet_range attendance_sheet_last_synced_at creator_user_id
      office_id division_id inserted_at updated_at
    ),
    "training_approvals" => ~w(
      id action actor_role_key from_status to_status notes training_activity_id acted_by_user_id
      inserted_at
    ),
    "registrations" => ~w(
      id status special_requirements review_notes submitted_at reviewed_at training_activity_id
      registrant_user_id reviewer_user_id manual_participant_name manual_participant_email
      inserted_at updated_at
    ),
    "external_registration_submissions" => ~w(
      id full_name email employee_number office_name source_reference special_requirements
      review_notes status submitted_at reviewed_at training_activity_id matched_user_id
      imported_registration_id reviewer_user_id inserted_at updated_at
    ),
    "attendance_sessions" => ~w(
      id name session_date starts_at ends_at status training_activity_id opened_by_user_id
      closed_by_user_id inserted_at updated_at
    ),
    "attendance_records" => ~w(
      id status notes marked_at attendance_session_id registration_id marked_by_user_id
      inserted_at updated_at
    ),
    "evaluation_submissions" => ~w(
      id overall_rating feedback application_plan submitted_at registration_id submitted_by_user_id
      inserted_at updated_at
    ),
    "certificate_records" => ~w(
      id certificate_number verification_code verification_status certificate_type issued_on
      delivery_status emailed_at downloaded_at registration_id issued_by_user_id inserted_at updated_at
    ),
    "certificate_layout_settings" => ~w(
      id scope_key certificate_size layout_style accent_color header_title header_subtitle body_intro
      completion_statement signature_label issuing_office_label asset_path asset_name
      asset_content_type inserted_at updated_at
    )
  }

  def expected_tables, do: @expected_tables

  def check(repo \\ Repo) do
    actual_tables = fetch_tables(repo)
    actual_columns = fetch_columns(repo, Map.keys(@expected_tables))

    report(@expected_tables, actual_tables, actual_columns)
  end

  def report(expected_tables, actual_tables, actual_columns) do
    table_set = MapSet.new(actual_tables)

    missing_tables =
      expected_tables
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(table_set, &1))
      |> Enum.sort()

    missing_columns =
      expected_tables
      |> Enum.reduce(%{}, fn {table_name, expected_columns}, acc ->
        actual = Map.get(actual_columns, table_name, [])
        missing = expected_columns -- actual

        if missing == [] do
          acc
        else
          Map.put(acc, table_name, missing)
        end
      end)

    %{
      status: schema_status(missing_tables, missing_columns),
      checked_tables: map_size(expected_tables),
      checked_columns: expected_column_count(expected_tables),
      missing_tables: missing_tables,
      missing_columns: missing_columns
    }
  end

  defp fetch_tables(repo) do
    SQL.query!(
      repo,
      """
      select table_name
      from information_schema.tables
      where table_schema = 'public'
      order by table_name
      """,
      []
    ).rows
    |> Enum.map(&hd/1)
  end

  defp fetch_columns(repo, table_names) do
    SQL.query!(
      repo,
      """
      select table_name, column_name
      from information_schema.columns
      where table_schema = 'public' and table_name = any($1)
      order by table_name, ordinal_position
      """,
      [table_names]
    ).rows
    |> Enum.reduce(%{}, fn [table_name, column_name], acc ->
      Map.update(acc, table_name, [column_name], &[column_name | &1])
    end)
    |> Map.new(fn {table_name, columns} -> {table_name, Enum.reverse(columns)} end)
  end

  defp expected_column_count(expected_tables) do
    Enum.reduce(expected_tables, 0, fn {_table_name, columns}, acc -> acc + length(columns) end)
  end

  defp schema_status([], missing_columns) when missing_columns == %{}, do: :ok
  defp schema_status(_missing_tables, _missing_columns), do: :error
end
