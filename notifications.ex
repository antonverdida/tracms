defmodule Tracms.Notifications do
  alias Ecto.Multi
  alias Tracms.Notifications.Delivery
  alias Tracms.Notifications.RegistrationSubmissionWorker
  alias Tracms.Registrations.Notifier
  alias Tracms.Repo

  def enqueue_registration_submission(registration) do
    Multi.new()
    |> Multi.insert(
      :delivery,
      Delivery.changeset(%Delivery{}, %{
        type: "registration_submitted",
        recipient_user_id: registration.registrant_user_id,
        registration_id: registration.id,
        training_activity_id: registration.training_activity_id
      })
    )
    |> Oban.insert(:job, fn %{delivery: delivery} ->
      RegistrationSubmissionWorker.new(%{"delivery_id" => delivery.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{delivery: delivery}} -> {:ok, delivery}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def deliver_registration_submission(delivery_id) do
    delivery =
      Repo.get!(Delivery, delivery_id) |> Repo.preload([:recipient_user, :training_activity])

    case Notifier.deliver_submission_confirmation(
           delivery.recipient_user,
           delivery.training_activity
         ) do
      :sent ->
        update(delivery, %{status: :delivered, delivered_at: DateTime.utc_now(:second)})

      :skipped ->
        update(delivery, %{status: :skipped})

      {:error, reason} ->
        _ = update(delivery, %{status: :failed, failed_at: DateTime.utc_now(:second)})
        {:error, reason}
    end
  end

  defp update(delivery, attrs), do: delivery |> Delivery.changeset(attrs) |> Repo.update()
end
