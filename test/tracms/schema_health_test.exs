defmodule Tracms.SchemaHealthTest do
  use Tracms.DataCase, async: true

  alias Tracms.SchemaHealth

  test "check/1 reports a healthy schema for the current test database" do
    assert %{
             status: :ok,
             checked_tables: checked_tables,
             checked_columns: checked_columns,
             missing_tables: [],
             missing_columns: %{}
           } = SchemaHealth.check()

    assert checked_tables > 0
    assert checked_columns > 0
  end

  test "report/3 detects missing critical tables and columns" do
    expected_tables = %{
      "training_activities" =>
        ~w(id title registration_form_id registration_form_url registration_sheet_id attendance_sheet_id),
      "training_approvals" => ~w(id notes)
    }

    actual_tables = ["training_activities"]
    actual_columns = %{"training_activities" => ~w(id title)}

    assert %{
             status: :error,
             missing_tables: ["training_approvals"],
             missing_columns: %{
               "training_activities" => [
                 "registration_form_id",
                 "registration_form_url",
                 "registration_sheet_id",
                 "attendance_sheet_id"
               ]
             }
           } = SchemaHealth.report(expected_tables, actual_tables, actual_columns)
  end
end
