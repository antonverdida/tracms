defmodule Tracms.GoogleSheets.TestClient do
  @behaviour Tracms.GoogleSheets

  @impl true
  def fetch_values("sync-sheet-main", "Form Responses 1!A:F") do
    {:ok,
     %{
       headers: ["full_name", "email", "employee_number", "office_name", "source_reference"],
       rows: [
         [
           "Sync Participant",
           "sync.participant@example.com",
           "EMP-SYNC-1",
           "DepEd Region IX",
           "response-001"
         ],
         [
           "Missing Email",
           "",
           "EMP-SYNC-2",
           "Unknown Office",
           "response-002"
         ]
       ]
     }}
  end

  def fetch_values("sync-sheet-empty", "Form Responses 1!A:F") do
    {:error, :google_sheet_has_no_values}
  end

  def fetch_values("attendance-sheet-main", "Attendance!A:C") do
    {:ok,
     %{
       headers: ["email", "status", "notes"],
       rows: [
         ["attendance.participant@example.com", "present", "Arrived on time"],
         ["missing.participant@example.com", "late", "No approved registration"]
       ]
     }}
  end

  def fetch_values("attendance-sheet-invalid-headers", "Attendance!A:C") do
    {:ok,
     %{
       headers: ["name", "remarks"],
       rows: [
         ["Juan Dela Cruz", "Present"]
       ]
     }}
  end

  def fetch_values(_spreadsheet_id, _range) do
    {:error, :google_sheet_not_found}
  end
end
