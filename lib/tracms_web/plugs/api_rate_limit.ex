defmodule TracmsWeb.Plugs.ApiRateLimit do
  @moduledoc false

  import Plug.Conn

  alias TracmsWeb.ApiRateLimiter

  def init(opts), do: opts

  def call(conn, _opts) do
    case ApiRateLimiter.check(conn.remote_ip) do
      {:allow, limit, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))

      {:deny, limit, retry_after_ms} ->
        retry_after = max(1, ceil(retry_after_ms / 1_000))

        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("retry-after", to_string(retry_after))
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", "0")
        |> send_resp(
          429,
          Jason.encode!(%{error: %{code: "rate_limited", message: "Too many requests."}})
        )
        |> halt()
    end
  end
end
