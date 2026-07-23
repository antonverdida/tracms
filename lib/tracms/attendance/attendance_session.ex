defmodule Tracms.Attendance.AttendanceSession do
  use Ecto.Schema
  import Ecto.Changeset

  alias Tracms.Accounts.User
  alias Tracms.Trainings.TrainingActivity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @status_values [:draft, :open, :closed]

  schema "attendance_sessions" do
    field :name, :string
    field :session_date, :date
    field :starts_at, :time
    field :ends_at, :time
    field :status, Ecto.Enum, values: @status_values, default: :draft

    belongs_to :training_activity, TrainingActivity
    belongs_to :opened_by_user, User
    belongs_to :closed_by_user, User

    timestamps(type: :utc_datetime)
  end

  def status_values, do: @status_values

  def changeset(attendance_session, attrs) do
    attendance_session
    |> cast(attrs, [
      :name,
      :session_date,
      :starts_at,
      :ends_at,
      :status,
      :training_activity_id,
      :opened_by_user_id,
      :closed_by_user_id
    ])
    |> validate_required([
      :name,
      :session_date,
      :starts_at,
      :ends_at,
      :status,
      :training_activity_id
    ])
    |> validate_length(:name, max: 160)
    |> validate_time_window()
    |> unique_constraint([:training_activity_id, :session_date, :name])
    |> assoc_constraint(:training_activity)
    |> assoc_constraint(:opened_by_user)
    |> assoc_constraint(:closed_by_user)
  end

  defp validate_time_window(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    cond do
      is_nil(starts_at) or is_nil(ends_at) ->
        changeset

      Time.compare(ends_at, starts_at) != :gt ->
        add_error(changeset, :ends_at, "must be later than the session start time")

      true ->
        changeset
    end
  end
end
