defmodule TracmsWeb.Plugs.ApiCors do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_req_header(conn, "origin") do
      [origin] -> allow_origin(conn, origin)
      _ -> conn
    end
  end

  defp allowed_origins, do: Application.get_env(:tracms, :api_allowed_origins, [])

  defp allow_origin(conn, origin) do
    if origin in allowed_origins() do
      conn
      |> put_resp_header("access-control-allow-origin", origin)
      |> put_resp_header("access-control-allow-methods", "GET, OPTIONS")
      |> put_resp_header("access-control-allow-headers", "Content-Type")
      |> put_resp_header("vary", "Origin")
    else
      conn
    end
  end
end
