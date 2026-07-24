defmodule Tracms.Trainings do
  @moduledoc """
  The Trainings context.
  """

  import Ecto.Changeset, only: [put_change: 3]
  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias Tracms.Accounts.Scope
  alias Tracms.Attendance
  alias Tracms.GoogleForms
  alias Tracms.GoogleForms.Template
  alias Tracms.Repo
  alias Tracms.Trainings.TrainingApproval
  alias Tracms.Trainings.TrainingActivity

  @preloads [:creator_user, :office, :division]
  @approval_preloads [acted_by_user: [:role, :office]]

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

  def list_training_approvals(scope, training_id) do
    training_activity = get_training_activity!(scope, training_id)

    TrainingApproval
    |> where([approval], approval.training_activity_id == ^training_activity.id)
    |> preload(^@approval_preloads)
    |> order_by([approval], asc: approval.inserted_at)
    |> Repo.all()
  end

  def create_training_activity(scope, attrs) do
    if Scope.training_manager?(scope) do
      Multi.new()
      |> Multi.insert(
        :training_activity,
        %TrainingActivity{}
        |> TrainingActivity.changeset(attrs)
        |> put_scope_defaults(scope)
      )
      |> Multi.run(:approval_entry, fn repo, %{training_activity: training_activity} ->
        insert_training_approval(repo, scope, training_activity, %{
          action: :created,
          from_status: nil,
          to_status: training_activity.status
        })
      end)
      |> Repo.transaction()
      |> transaction_result(:training_activity)
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

  def update_training_integration(scope, %TrainingActivity{} = training_activity, attrs) do
    if Scope.training_manager?(scope) and accessible_to_scope?(scope, training_activity) do
      training_activity
      |> TrainingActivity.integration_changeset(attrs)
      |> Repo.update()
      |> preload_result()
    else
      {:error, :unauthorized}
    end
  end

  def generate_google_form(scope, %TrainingActivity{} = training_activity, kind) do
    with true <- Scope.training_manager?(scope),
         true <- accessible_to_scope?(scope, training_activity),
         {:ok, form_payload} <- build_google_form_payload(scope, training_activity, kind),
         {:ok, generated_form} <- GoogleForms.create_form(form_payload) do
      update_training_integration(
        scope,
        training_activity,
        generated_form_attrs(kind, generated_form)
      )
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
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

  def return_action_label(scope, %TrainingActivity{status: status}) do
    cond do
      status == :pending_division_approval and
          (Scope.division_admin?(scope) or Scope.regional_admin?(scope)) ->
        "Return to coordinator for revision"

      status == :pending_region_approval and Scope.regional_admin?(scope) ->
        "Return for revision"

      true ->
        nil
    end
  end

  def advance_training_activity(scope, %TrainingActivity{} = training_activity) do
    with true <- Scope.training_manager?(scope),
         true <- accessible_to_scope?(scope, training_activity),
         {:ok, attrs, action} <- next_transition(scope, training_activity) do
      Multi.new()
      |> Multi.update(
        :training_activity,
        training_activity
        |> TrainingActivity.changeset(attrs)
      )
      |> Multi.run(:approval_entry, fn repo, %{training_activity: updated_training_activity} ->
        insert_training_approval(repo, scope, updated_training_activity, %{
          action: action,
          from_status: training_activity.status,
          to_status: updated_training_activity.status
        })
      end)
      |> Repo.transaction()
      |> transaction_result(:training_activity)
      |> preload_result()
    else
      false -> {:error, :unauthorized}
      {:error, reason} -> {:error, reason}
    end
  end

  def return_training_activity_for_revision(scope, %TrainingActivity{} = training_activity, notes) do
    with true <- Scope.training_manager?(scope),
         true <- accessible_to_scope?(scope, training_activity),
         :ok <- validate_revision_notes(notes),
         {:ok, attrs} <- revision_return_transition(scope, training_activity) do
      Multi.new()
      |> Multi.update(
        :training_activity,
        training_activity
        |> TrainingActivity.changeset(attrs)
      )
      |> Multi.run(:approval_entry, fn repo, %{training_activity: updated_training_activity} ->
        insert_training_approval(repo, scope, updated_training_activity, %{
          action: :returned_for_revision,
          from_status: training_activity.status,
          to_status: updated_training_activity.status,
          notes: String.trim(notes)
        })
      end)
      |> Repo.transaction()
      |> transaction_result(:training_activity)
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
        {:ok, %{status: :pending_division_approval}, :submitted_to_division}

      Scope.division_admin?(scope) ->
        {:ok, %{status: :pending_region_approval}, :submitted_to_region}

      Scope.regional_admin?(scope) ->
        {:ok, %{status: :published, published_at: DateTime.utc_now(:second)}, :published}

      true ->
        {:error, :unauthorized}
    end
  end

  defp next_transition(scope, %TrainingActivity{status: :pending_division_approval}) do
    if Scope.division_admin?(scope) or Scope.regional_admin?(scope) do
      {:ok, %{status: :pending_region_approval}, :advanced_to_region_approval}
    else
      {:error, :unauthorized}
    end
  end

  defp next_transition(scope, %TrainingActivity{status: :pending_region_approval}) do
    if Scope.regional_admin?(scope) do
      {:ok, %{status: :published, published_at: DateTime.utc_now(:second)}, :published}
    else
      {:error, :unauthorized}
    end
  end

  defp next_transition(_scope, _training_activity), do: {:error, :invalid_transition}

  defp revision_return_transition(
         scope,
         %TrainingActivity{status: :pending_division_approval} = training_activity
       ) do
    if (Scope.division_admin?(scope) or Scope.regional_admin?(scope)) and
         accessible_to_scope?(scope, training_activity) do
      {:ok, %{status: :draft}}
    else
      {:error, :unauthorized}
    end
  end

  defp revision_return_transition(
         scope,
         %TrainingActivity{status: :pending_region_approval} = training_activity
       ) do
    if Scope.regional_admin?(scope) and accessible_to_scope?(scope, training_activity) do
      {:ok, %{status: :draft}}
    else
      {:error, :unauthorized}
    end
  end

  defp revision_return_transition(_scope, _training_activity), do: {:error, :invalid_transition}

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

  defp validate_revision_notes(notes) when is_binary(notes) do
    if String.trim(notes) == "" do
      {:error, :missing_notes}
    else
      :ok
    end
  end

  defp validate_revision_notes(_notes), do: {:error, :missing_notes}

  defp build_google_form_payload(scope, training_activity, :registration) do
    {:ok,
     Template.registration_form(training_activity)
     |> Map.put(:share_with, scope.user.email)}
  end

  defp build_google_form_payload(scope, training_activity, :attendance) do
    attendance_sessions = Attendance.list_sessions(scope, training_activity.id)

    {:ok,
     Template.attendance_form(training_activity, attendance_sessions)
     |> Map.put(:share_with, scope.user.email)}
  end

  defp build_google_form_payload(_scope, _training_activity, _kind),
    do: {:error, :invalid_google_form_kind}

  defp generated_form_attrs(:registration, generated_form) do
    %{
      registration_form_id: generated_form.form_id,
      registration_form_url: generated_form.responder_uri
    }
  end

  defp generated_form_attrs(:attendance, generated_form) do
    %{
      attendance_form_id: generated_form.form_id,
      attendance_form_url: generated_form.responder_uri
    }
  end

  defp insert_training_approval(repo, scope, training_activity, attrs) do
    %TrainingApproval{}
    |> TrainingApproval.changeset(
      Map.merge(attrs, %{
        actor_role_key: scope.role_key || "unknown",
        training_activity_id: training_activity.id,
        acted_by_user_id: scope.user && scope.user.id
      })
    )
    |> repo.insert()
  end

  defp transaction_result({:ok, changes}, key), do: {:ok, Map.fetch!(changes, key)}
  defp transaction_result({:error, _step, reason, _changes}, _key), do: {:error, reason}
end
