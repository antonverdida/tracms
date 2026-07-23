defmodule TracmsWeb.PageController do
  use TracmsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
