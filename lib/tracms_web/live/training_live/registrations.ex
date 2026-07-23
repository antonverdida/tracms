defmodule TracmsWeb.TrainingLive.Registrations do
  use TracmsWeb, :live_view

  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    {:ok,
     socket
     |> assign(:page_title, "Training Registrations")
     |> assign(:training_activity, training_activity)
     |> load_registrations()}
  end

  @impl true
  def handle_event("review", %{"id" => id, "status" => status}, socket) do
    registration =
      Enum.find(socket.assigns.registrations, fn registration -> registration.id == id end)

    status = String.to_existing_atom(status)

    case registration &&
           Registrations.review_registration(socket.assigns.current_scope, registration, status) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration updated successfully.")
         |> load_registrations()}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update this registration.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="eyebrow">Registration management</p>
            <h1 class="section-title">{@training_activity.title}</h1>
            <p class="section-copy">
              Review submitted participants and update registration decisions.
            </p>
          </div>
          <div class="flex gap-3">
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
          </div>
        </div>

        <%= if @registrations == [] do %>
          <section class="panel">
            <h2 class="section-title">No registrations yet</h2>
            <p class="section-copy">
              Submitted participant registrations for this training will appear here.
            </p>
          </section>
        <% else %>
          <section class="panel">
            <.table id="training-registrations" rows={@registrations}>
              <:col :let={registration} label="Participant">
                <div class="font-semibold">
                  {registration.registrant_user.full_name || registration.registrant_user.email}
                </div>
                <div class="text-sm text-[var(--tracms-text-muted)]">
                  {registration.registrant_user.email}
                </div>
              </:col>
              <:col :let={registration} label="Submitted">
                {registration.submitted_at}
              </:col>
              <:col :let={registration} label="Requirements">
                {registration.special_requirements || "None"}
              </:col>
              <:col :let={registration} label="Status">
                <span class="badge-soft">{Registrations.format_status(registration.status)}</span>
              </:col>
              <:col :let={registration} label="Review notes">
                {registration.review_notes || "No review notes yet"}
              </:col>
              <:action :let={registration}>
                <.button
                  :if={registration.status in [:submitted, :waitlisted]}
                  phx-click="review"
                  phx-value-id={registration.id}
                  phx-value-status="approved"
                  variant="secondary"
                >
                  Approve
                </.button>
              </:action>
              <:action :let={registration}>
                <.button
                  :if={registration.status in [:submitted, :approved]}
                  phx-click="review"
                  phx-value-id={registration.id}
                  phx-value-status="waitlisted"
                  variant="ghost"
                >
                  Waitlist
                </.button>
              </:action>
              <:action :let={registration}>
                <.button
                  :if={registration.status in [:submitted, :approved, :waitlisted]}
                  phx-click="review"
                  phx-value-id={registration.id}
                  phx-value-status="rejected"
                  variant="danger"
                >
                  Reject
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
      Registrations.list_training_registrations(
        socket.assigns.current_scope,
        socket.assigns.training_activity.id
      )
    )
  end
end
