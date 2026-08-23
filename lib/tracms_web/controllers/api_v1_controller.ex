defmodule TracmsWeb.ApiV1Controller do
  use TracmsWeb, :controller

  def options(conn, _params), do: send_resp(conn, :no_content, "")
end
