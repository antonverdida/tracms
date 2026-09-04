defmodule Tracms.Notifications.TrainingReminderSchedulerWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 3

  alias Tracms.Notifications

  @impl Oban.Worker
  def perform(_job) do
    Notifications.enqueue_due_training_reminders()
    :ok
  end
end
