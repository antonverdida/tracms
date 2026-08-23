defmodule TracmsWeb.AttendanceExportHTML do
  use TracmsWeb, :html

  alias Tracms.Attendance
  alias Tracms.Registrations

  embed_templates "attendance_export_html/*"

  def participant_name(entry) do
    Registrations.participant_name(entry.registration)
  end

  def organization_name(entry) do
    Registrations.participant_organization(entry.registration)
  end

  def registration_status_label(status) when status in [:submitted, :approved, :waitlisted],
    do: "Registered"

  def registration_status_label(_status), do: "Cancelled"

  def attendance_status_label(entry) do
    case Attendance.manual_status(entry.record) do
      :present -> "Present"
      :absent -> "Absent"
      nil -> "Not yet recorded"
    end
  end

  def remarks_label(entry) do
    if entry.record && entry.record.notes do
      entry.record.notes
    else
      "No remarks"
    end
  end

  def recorded_at_label(entry) do
    if entry.record do
      format_datetime(entry.record.marked_at)
    else
      "Not yet recorded"
    end
  end
end
