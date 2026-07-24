defmodule TracmsWeb.TrainingManagerAuth do
  use TracmsWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias Tracms.Accounts.Scope

  def init(opts), do: opts

  def call(conn, opts), do: require_training_manager(conn, opts)

  def require_training_manager(conn, _opts) do
    if Scope.training_manager?(conn.assigns.current_scope) do
      conn
    else
      conn
      |> put_flash(:error, "You do not have access to training management.")
      |> redirect(to: ~p"/dashboard")
      |> halt()
    end
  end
end
