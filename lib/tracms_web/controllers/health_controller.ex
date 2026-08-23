defmodule TracmsWeb.HealthController do
  use TracmsWeb, :controller

  alias Tracms.Repo

  def liveness(conn, _params) do
    json(conn, %{status: "ok"})
  end

  def readiness(conn, _params) do
    case Repo.query("SELECT 1") do
      {:ok, _result} ->
        json(conn, %{status: "ok"})

      {:error, _reason} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unavailable"})
    end
  end
end
