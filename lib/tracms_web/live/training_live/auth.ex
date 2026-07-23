defmodule TracmsWeb.TrainingLive.Auth do
  use TracmsWeb, :verified_routes

  import Phoenix.LiveView

  alias Tracms.Accounts.Scope

  def on_mount(:require_training_manager, _params, _session, socket) do
    scope = socket.assigns.current_scope

    if Scope.training_manager?(scope) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have access to training management.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end
end
