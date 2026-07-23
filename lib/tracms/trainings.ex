defmodule Tracms.Trainings do
  @moduledoc """
  The Trainings context.
  """

  import Ecto.Changeset, only: [put_change: 3]
  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Repo
  alias Tracms.Trainings.TrainingActivity

  @preloads [:creator_user, :office, :division]

  def list_training_activities(scope) do
    if Scope.training_manager?(scope) do
      TrainingActivity
      |> scope_query(scope)
      |> preload(^@preloads)
      |> order_by([training], desc: training.inserted_at)
      |> Repo.all()
    else
      []
    end
  end

  def get_training_activity!(scope, id) do
    TrainingActivity
    |> scope_query(scope)
    |> preload(^@preloads)
    |> Repo.get!(id)
  end

  def create_training_activity(scope, attrs) do
    if Scope.training_manager?(scope) do
      %TrainingActivity{}
      |> TrainingActivity.changeset(attrs)
      |> put_scope_defaults(scope)
      |> Repo.insert()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def update_training_activity(scope, %TrainingActivity{} = training_activity, attrs) do
    if Scope.training_manager?(scope) and accessible_to_scope?(scope, training_activity) and
         editable?(training_activity) do
      training_activity
      |> TrainingActivity.changeset(attrs)
      |> put_scope_ownership(scope)
      |> Repo.update()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def change_training_activity(%TrainingActivity{} = training_activity, attrs \\ %{}) do
    TrainingActivity.changeset(training_activity, attrs)
  end

  def editable?(%TrainingActivity{status: status}) do
    status in [:draft, :pending_division_approval, :pending_region_approval]
  end

  def next_action_label(scope, %TrainingActivity{status: status}) do
    cond do
      status == :draft and Scope.coordinator?(scope) ->
        "Submit to division"

      status == :draft and Scope.division_admin?(scope) ->
        "Submit to region"

      status == :draft and Scope.regional_admin?(scope) ->
        "Publish training"

      status == :pending_division_approval and
          (Scope.division_admin?(scope) or Scope.regional_admin?(scope)) ->
        "Advance to region approval"

      status == :pending_region_approval and Scope.regional_admin?(scope) ->
        "Publish training"

      true ->
        nil
    end
  end

  def advance_training_activity(scope, %TrainingActivity{} = training_activity) do
    with true <- Scope.training_manager?(scope),
         true <- accessible_to_scope?(scope, training_activity),
         {:ok, attrs} <- next_transition(scope, training_activity) do
      training_activity
      |> TrainingActivity.changeset(attrs)
      |> Repo.update()
      |> preload_result()
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def format_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp scope_query(query, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        query

      Scope.division_admin?(scope) and scope.division_id ->
        where(query, [training], training.division_id == ^scope.division_id)

      Scope.coordinator?(scope) and scope.office_id ->
        where(query, [training], training.office_id == ^scope.office_id)

      true ->
        where(query, [training], false)
    end
  end

  defp put_scope_defaults(changeset, scope) do
    changeset
    |> put_change(:creator_user_id, scope.user.id)
    |> put_scope_ownership(scope)
  end

  defp put_scope_ownership(changeset, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        changeset
        |> maybe_put_change(:office_id, scope.office_id)
        |> maybe_put_change(:division_id, scope.division_id)

      Scope.division_admin?(scope) ->
        changeset
        |> maybe_put_change(:office_id, scope.office_id)
        |> put_change(:division_id, scope.division_id)

      Scope.coordinator?(scope) ->
        changeset
        |> put_change(:office_id, scope.office_id)
        |> put_change(:division_id, scope.division_id)

      true ->
        changeset
    end
  end

  defp maybe_put_change(changeset, _field, nil), do: changeset
  defp maybe_put_change(changeset, field, value), do: put_change(changeset, field, value)

  defp next_transition(scope, %TrainingActivity{status: :draft}) do
    cond do
      Scope.coordinator?(scope) ->
        {:ok, %{status: :pending_division_approval}}

      Scope.division_admin?(scope) ->
        {:ok, %{status: :pending_region_approval}}

      Scope.regional_admin?(scope) ->
        {:ok, %{status: :published, published_at: DateTime.utc_now(:second)}}

      true ->
        {:error, :unauthorized}
    end
  end

  defp next_transition(scope, %TrainingActivity{status: :pending_division_approval}) do
    if Scope.division_admin?(scope) or Scope.regional_admin?(scope) do
      {:ok, %{status: :pending_region_approval}}
    else
      {:error, :unauthorized}
    end
  end

  defp next_transition(scope, %TrainingActivity{status: :pending_region_approval}) do
    if Scope.regional_admin?(scope) do
      {:ok, %{status: :published, published_at: DateTime.utc_now(:second)}}
    else
      {:error, :unauthorized}
    end
  end

  defp next_transition(_scope, _training_activity), do: {:error, :invalid_transition}

  defp accessible_to_scope?(scope, training_activity) do
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

  defp preload_result({:ok, training_activity}),
    do: {:ok, Repo.preload(training_activity, @preloads)}

  defp preload_result(other), do: other
end
