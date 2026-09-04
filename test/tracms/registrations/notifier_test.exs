defmodule Tracms.Registrations.NotifierTest do
  use Tracms.DataCase, async: false

  import Tracms.RegistrationsFixtures
  import Tracms.AttendanceFixtures
  import Tracms.TrainingsFixtures

  alias Tracms.Accounts
  alias Tracms.Attendance
  alias Tracms.Notifications
  alias Tracms.Notifications.Delivery
  alias Tracms.Notifications.RegistrationSubmissionWorker
  alias Tracms.Notifications.TrainingReminderSchedulerWorker
  alias Tracms.Registrations
  alias Tracms.Repo
  alias Tracms.Trainings

  test "sends a confirmation when a participant submits a registration" do
    participant = participant_scope_fixture(%{full_name: "Maria Participant"})
    training = published_training_fixture()
    discard_emails()

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    delivery = Repo.get_by!(Delivery, registration_id: registration.id)

    assert :ok =
             RegistrationSubmissionWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    assert_receive {:email, email}
    assert email.to == [{"", participant.user.email}]
    assert email.subject == "Registration received: #{training.title}"
    assert email.text_body =~ "Maria Participant"
    assert email.html_body =~ "registration for"
  end

  test "does not send a confirmation when registration updates are disabled" do
    participant = participant_scope_fixture()

    assert {:ok, _user} =
             Accounts.update_user_notification_preferences(participant.user, %{
               "notification_preferences" => %{"registration_updates" => "false"}
             })

    training = published_training_fixture()
    discard_emails()

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    delivery = Repo.get_by!(Delivery, registration_id: registration.id)

    assert :ok =
             RegistrationSubmissionWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    refute_receive {:email, _email}
    assert Repo.get!(Delivery, delivery.id).status == :skipped
  end

  test "queues and sends a registration approval outcome" do
    participant = participant_scope_fixture()
    training = published_training_fixture()
    manager = training_manager_scope_fixture("regional_admin")

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    discard_emails()

    assert {:ok, _reviewed_registration} =
             Registrations.review_registration(manager.scope, registration, :approved)

    delivery =
      Repo.get_by!(Delivery, registration_id: registration.id, type: "registration_approved")

    assert :ok =
             RegistrationSubmissionWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    assert_receive {:email, email}
    assert email.subject == "Registration Approved: #{training.title}"
    assert Repo.get!(Delivery, delivery.id).status == :delivered
  end

  test "queues one 24-hour reminder for each approved participant and prevents duplicates" do
    manager = training_manager_scope_fixture("regional_admin")
    participant = participant_scope_fixture(%{full_name: "Reminder Participant"})

    training =
      training_activity_fixture(manager.scope, %{
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 1, :hour),
        starts_on: Date.add(Date.utc_today(), 1),
        ends_on: Date.add(Date.utc_today(), 1)
      })

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    assert {:ok, _registration} =
             Registrations.review_registration(manager.scope, registration, :approved)

    assert :ok = Notifications.enqueue_due_training_reminders()
    assert :ok = TrainingReminderSchedulerWorker.perform(%Oban.Job{})

    reminders =
      Repo.all(Delivery)
      |> Enum.filter(
        &(&1.registration_id == registration.id and &1.type == "training_reminder_24h")
      )

    assert [delivery] = reminders
    assert delivery.status == :queued

    assert :ok = Notifications.enqueue_due_training_reminders()

    assert 1 ==
             Repo.all(Delivery)
             |> Enum.count(
               &(&1.registration_id == registration.id and &1.type == "training_reminder_24h")
             )
  end

  test "delivers and skips training reminders according to notification preferences" do
    manager = training_manager_scope_fixture("regional_admin")
    participant = participant_scope_fixture(%{full_name: "Reminder Recipient"})

    training =
      training_activity_fixture(manager.scope, %{
        status: :published,
        published_at: DateTime.utc_now(:second),
        registration_deadline: DateTime.add(DateTime.utc_now(:second), 1, :hour),
        starts_on: Date.add(Date.utc_today(), 1),
        ends_on: Date.add(Date.utc_today(), 1)
      })

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    assert {:ok, _registration} =
             Registrations.review_registration(manager.scope, registration, :approved)

    discard_emails()
    assert :ok = Notifications.enqueue_due_training_reminders()

    delivery =
      Repo.get_by!(Delivery, registration_id: registration.id, type: "training_reminder_24h")

    assert :ok =
             RegistrationSubmissionWorker.perform(%Oban.Job{args: %{"delivery_id" => delivery.id}})

    assert_receive {:email, email}
    assert email.subject == "Training reminder: #{training.title}"
    assert Repo.get!(Delivery, delivery.id).status == :delivered

    skipped_participant = participant_scope_fixture()

    assert {:ok, _user} =
             Accounts.update_user_notification_preferences(skipped_participant.user, %{
               "notification_preferences" => %{"registration_updates" => "false"}
             })

    assert {:ok, skipped_registration} =
             Registrations.register_user_for_training(skipped_participant.scope, training.id)

    assert {:ok, _registration} =
             Registrations.review_registration(manager.scope, skipped_registration, :approved)

    assert :ok = Notifications.enqueue_due_training_reminders()

    skipped_delivery =
      Repo.get_by!(
        Delivery,
        registration_id: skipped_registration.id,
        type: "training_reminder_24h"
      )

    assert :ok =
             RegistrationSubmissionWorker.perform(%Oban.Job{
               args: %{"delivery_id" => skipped_delivery.id}
             })

    assert Repo.get!(Delivery, skipped_delivery.id).status == :skipped

    failed_delivery =
      Repo.insert!(
        Delivery.changeset(%Delivery{}, %{
          type: "training_reminder_failed_test",
          recipient_user_id: skipped_participant.user.id,
          registration_id: skipped_registration.id,
          training_activity_id: training.id
        })
      )

    assert {:error, ":unsupported_notification_type"} =
             RegistrationSubmissionWorker.perform(%Oban.Job{
               args: %{"delivery_id" => failed_delivery.id}
             })

    assert Repo.get!(Delivery, failed_delivery.id).status == :failed
  end

  test "queues an attendance follow-up for an approved participant without a session record" do
    manager = training_manager_scope_fixture("regional_admin")
    participant = participant_scope_fixture()
    training = training_activity_fixture(manager.scope, %{status: :published})

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    assert {:ok, _registration} =
             Registrations.review_registration(manager.scope, registration, :approved)

    session = attendance_session_fixture(training_manager: manager, training_activity: training)
    assert {:ok, session} = Attendance.open_session(manager.scope, session)
    assert {:ok, _session} = Attendance.close_session(manager.scope, session)

    delivery =
      Repo.all(Delivery)
      |> Enum.find(fn delivery ->
        delivery.registration_id == registration.id and
          String.starts_with?(delivery.type, "attendance_followup:")
      end)

    assert delivery
    assert delivery.status == :queued
  end

  test "queues an evaluation follow-up when an evaluation-required training completes" do
    manager = training_manager_scope_fixture("regional_admin")
    participant = participant_scope_fixture()

    training =
      training_activity_fixture(manager.scope, %{status: :published, evaluation_required: true})

    assert {:ok, registration} =
             Registrations.register_user_for_training(participant.scope, training.id)

    assert {:ok, _registration} =
             Registrations.review_registration(manager.scope, registration, :approved)

    assert {:ok, training} =
             Trainings.update_training_status(manager.scope, training, :registration_closed)

    assert {:ok, training} =
             Trainings.update_training_status(manager.scope, training, :in_progress)

    assert {:ok, _training} =
             Trainings.update_training_status(manager.scope, training, :completed)

    delivery =
      Repo.get_by!(Delivery, registration_id: registration.id, type: "evaluation_followup")

    assert delivery.status == :queued
  end

  defp discard_emails do
    receive do
      {:email, _email} -> discard_emails()
    after
      0 -> :ok
    end
  end
end
