defmodule TracmsWeb.PageControllerTest do
  use TracmsWeb.ConnCase

  test "GET / redirects visitors to sign in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log-in"
  end
end
