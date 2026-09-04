defmodule Tracms.Audit do
  @moduledoc """
  Append-only audit events for sensitive TRACMS operations.
  """

  import Ecto.Query, warn: false

  alias Tracms.Accounts.Scope
  alias Tracms.Accounts.User
  alias Tracms.Audit.AuditLog
  alias Tracms.Repo

  @preloads [actor_user: [:role], training_activity: [:office, :division]]

  def list(scope, filters \\ %{}) do
    if Scope.training_manager?(scope) do
      AuditLog
      |> join(:left, [audit_log], training in assoc(audit_log, :training_activity))
      |> scope_query(scope)
      |> filter_action(Map.get(filters, "action") || Map.get(filters, :action))
      |> preload([_audit_log, _training], ^@preloads)
      |> order_by([audit_log], desc: audit_log.inserted_at)
      |> limit(100)
      |> Repo.all()
    else
      []
    end
  end

  def action_options(scope) do
    scope
    |> list()
    |> Enum.map(& &1.action)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Lists the most recent auditable actions performed by one user.
  """
  def list_for_user(%User{id: user_id}, limit \\ 5) when is_integer(limit) and limit > 0 do
    AuditLog
    |> where([audit_log], audit_log.actor_user_id == ^user_id)
    |> preload(^@preloads)
    |> order_by([audit_log], desc: audit_log.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def log(repo \\ Repo, scope, attrs) when is_map(attrs) do
    with %Scope{user: %{id: actor_user_id}} <- scope do
      attrs =
        attrs
        |> stringify_keys()
        |> Map.put("actor_user_id", actor_user_id)

      %AuditLog{}
      |> AuditLog.changeset(attrs)
      |> repo.insert()
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp filter_action(query, nil), do: query
  defp filter_action(query, ""), do: query
  defp filter_action(query, action), do: where(query, [audit_log], audit_log.action == ^action)

  defp scope_query(query, scope) do
    cond do
      Scope.regional_admin?(scope) ->
        query

      Scope.division_admin?(scope) and scope.division_id ->
        where(query, [_audit_log, training], training.division_id == ^scope.division_id)

      Scope.coordinator?(scope) and scope.office_id ->
        where(query, [_audit_log, training], training.office_id == ^scope.office_id)

      true ->
        where(query, [_audit_log, _training], false)
    end
  end
end
