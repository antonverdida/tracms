defmodule Tracms.DocumentRequests do
  import Ecto.Query

  alias Tracms.Accounts.Scope
  alias Tracms.DocumentRequests.{DocumentControl, DocumentRequest}
  alias Tracms.Repo

  def list_requests(%Scope{} = scope) do
    DocumentRequest
    |> preload([:requester, :approved_by, :document_control])
    |> restrict_to_scope(scope)
    |> order_by([request], desc: request.inserted_at)
    |> Repo.all()
  end

  def change_request(%DocumentRequest{} = request, attrs \\ %{}),
    do: DocumentRequest.changeset(request, attrs)

  def create_request(%Scope{} = scope, attrs) do
    Repo.transaction(fn ->
      request_number = next_request_number()

      %DocumentRequest{requester_id: scope.user.id, request_number: request_number}
      |> DocumentRequest.changeset(attrs)
      |> Repo.insert!()
    end)
  end

  def create_document_control(%Scope{} = scope, %DocumentRequest{} = request, attrs) do
    if Scope.system_admin?(scope) do
      Repo.transaction(fn ->
        control =
          %DocumentControl{
            document_request_id: request.id,
            created_by_id: scope.user.id,
            approved_by_id: scope.user.id
          }
          |> DocumentControl.changeset(attrs)
          |> Repo.insert!()

        request
        |> Ecto.Changeset.change(status: :approved, approved_by_id: scope.user.id)
        |> Repo.update!()

        control
      end)
    else
      {:error, :unauthorized}
    end
  end

  defp next_request_number do
    year = Date.utc_today().year
    prefix = "DRF-#{year}-"

    next_serial =
      DocumentRequest
      |> where([request], like(request.request_number, ^"#{prefix}%"))
      |> select([request], request.request_number)
      |> Repo.all()
      |> Enum.map(&request_serial(&1, prefix))
      |> Enum.reject(&is_nil/1)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(1)

    prefix <> String.pad_leading(Integer.to_string(next_serial), 6, "0")
  end

  defp request_serial(request_number, prefix) do
    case request_number |> String.replace_prefix(prefix, "") |> Integer.parse() do
      {serial, ""} -> serial
      _other -> nil
    end
  end

  defp restrict_to_scope(query, scope) do
    if Scope.system_admin?(scope),
      do: query,
      else: where(query, [request], request.requester_id == ^scope.user.id)
  end
end
