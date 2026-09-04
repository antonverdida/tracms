defmodule Tracms.Notifications.RegistrationSubmissionWorker do
  use Oban.Worker, queue: :notifications, max_attempts: 5

  alias Tracms.Notifications

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"delivery_id" => delivery_id}}) do
    case Notifications.deliver_registration_notification(delivery_id) do
      {:ok, _delivery} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
