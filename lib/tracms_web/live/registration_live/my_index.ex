defmodule TracmsWeb.RegistrationLive.MyIndex do
  use TracmsWeb, :live_view

  alias Tracms.Registrations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Registrations")
     |> load_registrations()}
  end

  @impl true
  def handle_event("withdraw", %{"id" => id}, socket) do
    registration =
      Enum.find(socket.assigns.registrations, fn registration -> registration.id == id end)

    case registration &&
           Registrations.withdraw_registration(socket.assigns.current_scope, registration) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration withdrawn successfully.")
         |> load_registrations()}

      _ ->
        {:noreply, put_flash(socket, :error, "This registration cannot be withdrawn.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.header>
          My Registrations
          <:subtitle>
            Track the status of your submitted training registrations.
          </:subtitle>
          <:actions>
            <.button navigate={~p"/catalog/trainings"}>Browse trainings</.button>
          </:actions>
        </.header>

        <%= if @registrations == [] do %>
          <section class="panel">
            <h2 class="section-title">No registrations yet</h2>
            <p class="section-copy">
              Once you submit a training registration, it will appear here.
            </p>
          </section>
        <% else %>
          <section class="panel">
            <.table id="my-registrations" rows={@registrations}>
              <:col :let={registration} label="Training">
                <div class="font-semibold">{registration.training_activity.title}</div>
                <div class="text-sm text-[var(--tracms-text-muted)]">
                  {registration.training_activity.starts_on} to {registration.training_activity.ends_on}
                </div>
              </:col>
              <:col :let={registration} label="Submitted">
                {registration.submitted_at}
              </:col>
              <:col :let={registration} label="Status">
                <span class="badge-soft">{Registrations.format_status(registration.status)}</span>
              </:col>
              <:col :let={registration} label="Notes">
                {registration.review_notes || "No review notes yet"}
              </:col>
              <:action :let={registration}>
                <.button
                  :if={registration.status in [:submitted, :approved, :waitlisted]}
                  phx-click="withdraw"
                  phx-value-id={registration.id}
                  variant="ghost"
                >
                  Withdraw
                </.button>
              </:action>
            </.table>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_registrations(socket) do
    assign(
      socket,
      :registrations,
      Registrations.list_user_registrations(socket.assigns.current_scope)
    )
  end
end
