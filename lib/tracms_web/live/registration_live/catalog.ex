defmodule TracmsWeb.RegistrationLive.Catalog do
  use TracmsWeb, :live_view

  alias Tracms.Registrations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Available Trainings")
     |> load_catalog()}
  end

  @impl true
  def handle_event("register", %{"id" => id}, socket) do
    case Registrations.register_user_for_training(socket.assigns.current_scope, id) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration submitted successfully.")
         |> load_catalog()}

      {:error, :already_registered} ->
        {:noreply, put_flash(socket, :error, "You are already registered for this training.")}

      {:error, :capacity_reached} ->
        {:noreply, put_flash(socket, :error, "This training has reached its maximum capacity.")}

      {:error, :registration_closed} ->
        {:noreply, put_flash(socket, :error, "Registration for this training is already closed.")}

      {:error, :not_published} ->
        {:noreply, put_flash(socket, :error, "This training is not yet open for registration.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to submit your registration right now.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="catalog"
    >
      <div class="space-y-6">
        <.header>
          Available Trainings
          <:subtitle>
            Browse published training activities that are currently open for registration.
          </:subtitle>
          <:actions>
            <.button navigate={~p"/my/registrations"} variant="ghost">My registrations</.button>
          </:actions>
        </.header>

        <%= if @training_activities == [] do %>
          <section class="panel">
            <h2 class="section-title">No open trainings available</h2>
            <p class="section-copy">
              Published trainings with active registration windows will appear here.
            </p>
          </section>
        <% else %>
          <section class="panel space-y-5">
            <div class="feature-grid">
              <div :for={training <- @training_activities} class="feature-card space-y-4">
                <div>
                  <h2 class="feature-title">{training.title}</h2>
                  <p class="feature-copy">{training.description}</p>
                </div>

                <div class="badge-row">
                  <span class="badge-soft">{training.category}</span>
                  <span class="badge-soft">{training.starts_on}</span>
                  <span class="badge-soft">{Registrations.format_status(training.status)}</span>
                </div>

                <div class="text-sm text-[var(--tracms-text-muted)] space-y-1">
                  <p>Venue: {training.venue}</p>
                  <p>Deadline: {training.registration_deadline}</p>
                  <p>Capacity: {training.max_capacity}</p>
                </div>

                <div class="flex justify-end">
                  <.button phx-click="register" phx-value-id={training.id}>Register now</.button>
                </div>
              </div>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_catalog(socket) do
    assign(
      socket,
      :training_activities,
      Registrations.list_open_training_activities(socket.assigns.current_scope)
    )
  end
end
