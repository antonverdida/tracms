defmodule Tracms.Registrations do
  @moduledoc """
  The Registrations context.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Registrations.Registration
  alias Tracms.Repo
  alias Tracms.Trainings
  alias Tracms.Trainings.TrainingActivity

  @preloads [
    training_activity: [:office, :division],
    registrant_user: [:office, :role],
    reviewer_user: []
  ]

  def list_open_training_activities(scope) do
    if scope && scope.user do
      training_ids = registered_training_ids(scope)

      TrainingActivity
      |> where([training], training.status == :published)
      |> where([training], training.registration_opens_on <= ^Date.utc_today())
      |> where([training], training.registration_deadline >= ^DateTime.utc_now(:second))
      |> where([training], training.id not in ^training_ids)
      |> preload([:office, :division])
      |> order_by([training], asc: training.starts_on, asc: training.title)
      |> Repo.all()
    else
      []
    end
  end

  def list_user_registrations(scope) do
    if scope && scope.user do
      Registration
      |> where([registration], registration.registrant_user_id == ^scope.user.id)
      |> preload(^@preloads)
      |> order_by([registration], desc: registration.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_manageable_registrations(scope) do
    if Scope.training_manager?(scope) do
      Registration
      |> join(:inner, [registration], training in assoc(registration, :training_activity))
      |> scope_manageable_registrations(scope)
      |> preload(^@preloads)
      |> order_by([registration, _training], desc: registration.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def list_training_registrations(scope, training_id) do
    training_activity = Trainings.get_training_activity!(scope, training_id)

    Registration
    |> where([registration], registration.training_activity_id == ^training_activity.id)
    |> preload(^@preloads)
    |> order_by([registration], asc: registration.inserted_at)
    |> Repo.all()
  end

  def get_user_registration_for_training(scope, training_id) do
    if scope && scope.user do
      Registration
      |> Repo.get_by(training_activity_id: training_id, registrant_user_id: scope.user.id)
      |> maybe_preload_registration()
    end
  end

  def register_user_for_training(scope, training_id, attrs \\ %{}) do
    with {:ok, user_id} <- ensure_authenticated_scope(scope),
         %TrainingActivity{} = training_activity <- Repo.get(TrainingActivity, training_id),
         :ok <- ensure_training_open(training_activity),
         :ok <- ensure_capacity_available(training_activity),
         nil <- get_user_registration_for_training(scope, training_id) do
      %Registration{}
      |> Registration.changeset(%{
        training_activity_id: training_id,
        registrant_user_id: user_id,
        submitted_at: DateTime.utc_now(:second),
        special_requirements: attrs["special_requirements"] || attrs[:special_requirements]
      })
      |> Repo.insert()
      |> preload_result()
    else
      {:error, :unauthorized} -> {:error, :unauthorized}
      nil -> {:error, :training_not_found}
      {:error, reason} -> {:error, reason}
      %Registration{} -> {:error, :already_registered}
    end
  end

  def withdraw_registration(scope, %Registration{} = registration) do
    if scope && scope.user && registration.registrant_user_id == scope.user.id &&
         registration.status in [:submitted, :approved, :waitlisted] do
      registration
      |> Registration.changeset(%{
        status: :withdrawn,
        reviewed_at: DateTime.utc_now(:second)
      })
      |> Repo.update()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def review_registration(scope, %Registration{} = registration, status, notes \\ nil) do
    with true <- Scope.training_manager?(scope),
         true <- manageable_registration?(scope, registration),
         true <- status in [:approved, :rejected, :waitlisted] do
      registration
      |> Registration.changeset(%{
        status: status,
        review_notes: notes,
        reviewed_at: DateTime.utc_now(:second),
        reviewer_user_id: scope.user.id
      })
      |> Repo.update()
      |> preload_result()
    else
      false -> {:error, :unauthorized}
    end
  end

  def format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp registered_training_ids(scope) do
    from(registration in Registration,
      where:
        registration.registrant_user_id == ^scope.user.id and registration.status != :withdrawn,
      select: registration.training_activity_id
    )
    |> Repo.all()
  end

  defp ensure_authenticated_scope(%Scope{user: %{id: user_id}}), do: {:ok, user_id}
  defp ensure_authenticated_scope(_scope), do: {:error, :unauthorized}

  defp ensure_training_open(%TrainingActivity{
         status: :published,
         registration_opens_on: opens_on,
         registration_deadline: deadline
       }) do
    today = Date.utc_today()

    cond do
      Date.compare(opens_on, today) == :gt ->
        {:error, :registration_not_open}

      DateTime.compare(deadline, DateTime.utc_now(:second)) in [:gt, :eq] ->
        :ok

      true ->
        {:error, :registration_closed}
    end
  end

  defp ensure_training_open(%TrainingActivity{}), do: {:error, :not_published}

  defp ensure_capacity_available(%TrainingActivity{id: training_id, max_capacity: max_capacity}) do
    active_count =
      from(registration in Registration,
        where:
          registration.training_activity_id == ^training_id and
            registration.status in [:submitted, :approved, :waitlisted],
        select: count(registration.id)
      )
      |> Repo.one()

    if active_count < max_capacity do
      :ok
    else
      {:error, :capacity_reached}
    end
  end

  defp manageable_registration?(scope, registration) do
    training_activity =
      if Ecto.assoc_loaded?(registration.training_activity) do
        registration.training_activity
      else
        Repo.get(TrainingActivity, registration.training_activity_id)
      end

    cond do
      Scope.regional_admin?(scope) ->
        true

      Scope.division_admin?(scope) ->
        scope.division_id && training_activity.division_id == scope.division_id

      Scope.coordinator?(scope) ->
        scope.office_id && training_activity.office_id == scope.office_id

      true ->
        false
    end
  end

  defp maybe_preload_registration(nil), do: nil
  defp maybe_preload_registration(registration), do: Repo.preload(registration, @preloads)

  defp preload_result({:ok, registration}), do: {:ok, Repo.preload(registration, @preloads)}
  defp preload_result(other), do: other

  defp scope_manageable_registrations(query, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        query

      Scope.division_admin?(scope) and scope.division_id ->
        where(query, [_registration, training], training.division_id == ^scope.division_id)

      Scope.coordinator?(scope) and scope.office_id ->
        where(query, [_registration, training], training.office_id == ^scope.office_id)

      true ->
        where(query, [_registration, _training], false)
    end
  end
end
