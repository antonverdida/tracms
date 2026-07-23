defmodule Tracms.Attendance.AttendanceRecord do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Attendance.AttendanceSession
  alias Tracms.Registrations.Registration

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:present, :late, :excused, :absent]

  schema "attendance_records" do
    field :status, Ecto.Enum, values: @status_values
    field :notes, :string
    field :marked_at, :utc_datetime

    belongs_to :attendance_session, AttendanceSession
    belongs_to :registration, Registration
    belongs_to :marked_by_user, User

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  def changeset(attendance_record, attrs) do
    attendance_record
    |> cast(attrs, [
      :status,
      :notes,
      :marked_at,
      :attendance_session_id,
      :registration_id,
      :marked_by_user_id
    ])
    |> validate_required([
      :status,
      :marked_at,
      :attendance_session_id,
      :registration_id,
      :marked_by_user_id
    ])
    |> validate_length(:notes, max: 1_000)
    |> unique_constraint([:attendance_session_id, :registration_id])
    |> assoc_constraint(:attendance_session)
    |> assoc_constraint(:registration)
    |> assoc_constraint(:marked_by_user)
  end
end
