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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="trainings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Registration management"
          title={@training_activity.title}
          copy="Review submitted participants and update registration decisions."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <%= if @registrations == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-user-group"
              title="No registrations yet"
              copy="Submitted participant registrations for this training will appear here."
            />
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Participant queue"
              title="Registration decisions"
              meta={registration_caption(@registrations)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Submitted</th>
                    <th>Requirements</th>
                    <th>Status</th>
                    <th>Review notes</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={registration <- @registrations}>
                    <td>
                      <div class="portal-cell-title">{participant_name(registration)}</div>
                      <div class="portal-cell-meta">{registration.registrant_user.email}</div>
                    </td>
                    <td>{format_datetime(registration.submitted_at)}</td>
                    <td>{registration.special_requirements || "None"}</td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{registration_status_tone(registration.status)}"
                      ]}>
                        {Registrations.format_status(registration.status)}
                      </span>
                    </td>
                    <td>{registration.review_notes || "No review notes yet"}</td>
                    <td>
                      <div class="portal-action-stack">
                        <.button
                          :if={registration.status in [:submitted, :waitlisted]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="approved"
                          variant="secondary"
                        >
                          Approve
                        </.button>
                        <.button
                          :if={registration.status in [:submitted, :approved]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="waitlisted"
                          variant="ghost"
                        >
                          Waitlist
                        </.button>
                        <.button
                          :if={registration.status in [:submitted, :approved, :waitlisted]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="rejected"
                          variant="danger"
                        >
                          Reject
                        </.button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_registrations(socket) do
    registrations =
      Registrations.list_training_registrations(
        socket.assigns.current_scope,
        socket.assigns.training_activity.id
      )

    socket
    |> assign(:registrations, registrations)
    |> assign(:summary_cards, registration_summary_cards(registrations))
  end

  defp registration_summary_cards(registrations) do
    [
      summary_card("Total registrations", length(registrations), "Submitted participant records"),
      summary_card(
        "Pending review",
        Enum.count(registrations, &(&1.status == :submitted)),
        "Awaiting a registration decision"
      ),
      summary_card(
        "Approved",
        Enum.count(registrations, &(&1.status == :approved)),
        "Confirmed for participation"
      ),
      summary_card(
        "Waitlisted or rejected",
        Enum.count(registrations, &(&1.status in [:waitlisted, :rejected])),
        "Not yet confirmed for the training"
      )
    ]
  end

  defp registration_caption(registrations) do
    count = length(registrations)
    "Showing #{count} participant #{if(count == 1, do: "registration", else: "registrations")}."
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp registration_status_tone(:approved), do: "green"
  defp registration_status_tone(:submitted), do: "blue"
  defp registration_status_tone(:waitlisted), do: "amber"
  defp registration_status_tone(:rejected), do: "rose"
  defp registration_status_tone(_status), do: "slate"
end
