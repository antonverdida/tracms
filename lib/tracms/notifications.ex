defmodule Tracms.Notifications do
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Tracms.Attendance.AttendanceRecord
  alias Tracms.Attendance.AttendanceSession
  alias Tracms.Evaluations.EvaluationSubmission
  alias Tracms.Notifications.Delivery
  alias Tracms.Notifications.RegistrationSubmissionWorker
  alias Tracms.Registrations.Notifier
  alias Tracms.Registrations.Registration
  alias Tracms.Repo

  def enqueue_due_training_reminders do
    tomorrow = Date.add(Date.utc_today(), 1)

    Registration
    |> join(:inner, [registration], training in assoc(registration, :training_activity))
    |> where(
      [registration, training],
      registration.status == :approved and training.starts_on == ^tomorrow
    )
    |> where([_registration, training], training.status in [:published, :registration_closed])
    |> Repo.all()
    |> Enum.each(&enqueue_training_reminder/1)
  end

  def enqueue_training_reminder(registration),
    do: enqueue_registration_notification(registration, "training_reminder_24h")

  def enqueue_session_attendance_followups(%AttendanceSession{} = session) do
    Registration
    |> join(:left, [registration], record in AttendanceRecord,
      on:
        record.attendance_session_id == ^session.id and
          record.registration_id == registration.id
    )
    |> where(
      [registration, record],
      registration.training_activity_id == ^session.training_activity_id and
        registration.status == :approved and
        (is_nil(record.id) or record.status == :absent)
    )
    |> Repo.all()
    |> Enum.each(fn registration ->
      enqueue_registration_notification(registration, "attendance_followup:#{session.id}")
    end)
  end

  def enqueue_evaluation_followups(training_activity_id) do
    Registration
    |> join(:inner, [registration], training in assoc(registration, :training_activity))
    |> join(:left, [registration], submission in EvaluationSubmission,
      on: submission.registration_id == registration.id
    )
    |> where(
      [registration, training, submission],
      registration.training_activity_id == ^training_activity_id and
        registration.status == :approved and training.status == :completed and
        training.evaluation_required and is_nil(submission.id)
    )
    |> Repo.all()
    |> Enum.each(&enqueue_registration_notification(&1, "evaluation_followup"))
  end

  def enqueue_registration_submission(registration) do
    enqueue_registration_notification(registration, "registration_submitted")
  end

  def enqueue_registration_reviewed(registration)
      when registration.status in [:approved, :rejected, :waitlisted] do
    enqueue_registration_notification(registration, "registration_#{registration.status}")
  end

  def deliver_registration_notification(delivery_id) do
    delivery =
      Repo.get!(Delivery, delivery_id) |> Repo.preload([:recipient_user, :training_activity])

    result =
      case delivery.type do
        "registration_submitted" ->
          Notifier.deliver_submission_confirmation(
            delivery.recipient_user,
            delivery.training_activity
          )

        "registration_" <> status ->
          Notifier.deliver_review_outcome(
            delivery.recipient_user,
            delivery.training_activity,
            status
          )

        "training_reminder_24h" ->
          Notifier.deliver_training_reminder(delivery.recipient_user, delivery.training_activity)

        "attendance_followup:" <> _session_id ->
          Notifier.deliver_attendance_followup(
            delivery.recipient_user,
            delivery.training_activity
          )

        "evaluation_followup" ->
          Notifier.deliver_evaluation_followup(
            delivery.recipient_user,
            delivery.training_activity
          )

        _unsupported_type ->
          {:error, :unsupported_notification_type}
      end

    case result do
      :sent ->
        update_delivery(delivery, %{status: :delivered, delivered_at: DateTime.utc_now(:second)})

      :skipped ->
        update_delivery(delivery, %{status: :skipped})

      {:error, reason} ->
        _ = update_delivery(delivery, %{status: :failed, failed_at: DateTime.utc_now(:second)})
        {:error, reason}
    end
  end

  defp enqueue_registration_notification(registration, type) do
    changeset =
      Delivery.changeset(%Delivery{}, %{
        type: type,
        recipient_user_id: registration.registrant_user_id,
        registration_id: registration.id,
        training_activity_id: registration.training_activity_id
      })

    Multi.new()
    |> Multi.insert(:delivery, changeset)
    |> Oban.insert(:job, fn %{delivery: delivery} ->
      RegistrationSubmissionWorker.new(%{"delivery_id" => delivery.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delivery: delivery}} -> {:ok, delivery}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  defp update_delivery(delivery, attrs),
    do: delivery |> Delivery.changeset(attrs) |> Repo.update()
end
