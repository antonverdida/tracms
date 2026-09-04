defmodule Tracms.Registrations.Notifier do
  @moduledoc false

  import Swoosh.Email

  alias Tracms.Accounts.User
  alias Tracms.Mailer
  alias Tracms.Registrations.Registration

  def deliver_submission_confirmation(%User{} = user, training) when not is_nil(training) do
    deliver_submission_confirmation(%Registration{
      registrant_user: user,
      training_activity: training
    })
  end

  def deliver_submission_confirmation(%Registration{
        registrant_user: %User{} = user,
        training_activity: training
      })
      when not is_nil(training) do
    if registration_updates_enabled?(user) do
      new()
      |> to(user.email)
      |> from({"DepEd Region IX TRACMS", "noreply@tracms.local"})
      |> subject("Registration received: #{training.title}")
      |> text_body(registration_text_body(user, training))
      |> html_body(registration_html_body(user, training))
      |> Mailer.deliver()
      |> case do
        {:ok, _metadata} -> :sent
        {:error, reason} -> {:error, reason}
      end
    else
      :skipped
    end
  end

  def deliver_submission_confirmation(_registration), do: {:error, :missing_registration_context}

  def deliver_review_outcome(%User{} = user, training, status)
      when status in ["approved", "rejected", "waitlisted"] do
    if registration_updates_enabled?(user) do
      outcome = String.capitalize(status)

      new()
      |> to(user.email)
      |> from({"DepEd Region IX TRACMS", "noreply@tracms.local"})
      |> subject("Registration #{outcome}: #{training.title}")
      |> text_body("Your registration for #{training.title} is now #{status}.")
      |> html_body(
        "<p>Your registration for <strong>#{escape(training.title)}</strong> is now <strong>#{escape(status)}</strong>.</p>"
      )
      |> Mailer.deliver()
      |> case do
        {:ok, _metadata} -> :sent
        {:error, reason} -> {:error, reason}
      end
    else
      :skipped
    end
  end

  def deliver_training_reminder(%User{} = user, training) do
    if registration_updates_enabled?(user) do
      new()
      |> to(user.email)
      |> from({"DepEd Region IX TRACMS", "noreply@tracms.local"})
      |> subject("Training reminder: #{training.title}")
      |> text_body("Reminder: #{training.title} starts tomorrow on #{training.starts_on}.")
      |> html_body(
        "<p>Reminder: <strong>#{escape(training.title)}</strong> starts tomorrow on #{training.starts_on}.</p>"
      )
      |> Mailer.deliver()
      |> case do
        {:ok, _metadata} -> :sent
        {:error, reason} -> {:error, reason}
      end
    else
      :skipped
    end
  end

  def deliver_attendance_followup(%User{} = user, training) do
    deliver_followup(
      user,
      training,
      "Attendance follow-up: #{training.title}",
      "Please contact your training manager regarding your attendance for #{training.title}."
    )
  end

  def deliver_evaluation_followup(%User{} = user, training) do
    deliver_followup(
      user,
      training,
      "Evaluation required: #{training.title}",
      "Please submit your evaluation for #{training.title} to complete the training requirements."
    )
  end

  defp deliver_followup(user, _training, subject, body) do
    if registration_updates_enabled?(user) do
      new()
      |> to(user.email)
      |> from({"DepEd Region IX TRACMS", "noreply@tracms.local"})
      |> subject(subject)
      |> text_body(body)
      |> html_body("<p>#{escape(body)}</p>")
      |> Mailer.deliver()
      |> case do
        {:ok, _metadata} -> :sent
        {:error, reason} -> {:error, reason}
      end
    else
      :skipped
    end
  end

  defp registration_updates_enabled?(user) do
    user.notification_preferences
    |> User.default_notification_preferences()
    |> Map.fetch!("registration_updates")
  end

  defp registration_text_body(user, training) do
    """
    Hello #{user.full_name || user.email},

    We received your registration for #{training.title}.

    Your application is currently submitted for review. You will receive another update when its status changes.

    TRACMS
    Department of Education - Region IX
    """
  end

  defp registration_html_body(user, training) do
    participant_name = escape(user.full_name || user.email)
    training_title = escape(training.title)

    """
    <p>Hello #{participant_name},</p>
    <p>We received your registration for <strong>#{training_title}</strong>.</p>
    <p>Your application is currently submitted for review. You will receive another update when its status changes.</p>
    <p>TRACMS<br>Department of Education - Region IX</p>
    """
  end

  defp escape(value) do
    value
    |> to_string()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
