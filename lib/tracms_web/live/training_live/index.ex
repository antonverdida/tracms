defmodule TracmsWeb.TrainingLive.Index do
  use TracmsWeb, :live_view

  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Training Activities")
     |> load_trainings()}
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
          eyebrow="Training management"
          title="Training Activities"
          copy="Create, review, and monitor training activities for DepEd Region IX."
        >
          <:actions>
            <.button navigate={~p"/trainings/new"}>Create training</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <%= if @trainings == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-calendar-days"
              title="No training activities yet"
              copy="Start by creating the first training activity for your office or division."
            >
              <:actions>
                <.link
                  navigate={~p"/trainings/new"}
                  class="portal-link-button portal-link-button-primary"
                >
                  Create training
                </.link>
              </:actions>
            </.portal_empty_state>
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Current records"
              title="Managed trainings"
              meta={@managed_training_caption}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Training</th>
                    <th>Schedule</th>
                    <th>Registration</th>
                    <th>Modality</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={training <- @trainings}>
                    <td>
                      <div class="portal-cell-title">{training.title}</div>
                      <div class="portal-cell-meta">{training.category}</div>
                    </td>
                    <td>
                      <div>{format_date(training.starts_on)}</div>
                      <div class="portal-cell-meta">to {format_date(training.ends_on)}</div>
                    </td>
                    <td>
                      <div>{format_datetime(training.registration_deadline)}</div>
                    </td>
                    <td>{format_modality(training.modality)}</td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{training_status_tone(training.status)}"
                      ]}>
                        {Trainings.format_status(training.status)}
                      </span>
                    </td>
                    <td>
                      <div class="portal-inline-links">
                        <.link navigate={~p"/trainings/#{training.id}"} class="portal-table-link">
                          View
                        </.link>
                        <.link
                          :if={Trainings.editable?(training)}
                          navigate={~p"/trainings/#{training.id}/edit"}
                          class="portal-table-link"
                        >
                          Edit
                        </.link>
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

  defp load_trainings(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)

    socket
    |> assign(:trainings, trainings)
    |> assign(:summary_cards, training_summary_cards(trainings))
    |> assign(:managed_training_caption, managed_training_caption(trainings))
  end

  defp training_summary_cards(trainings) do
    [
      summary_card("Total trainings", length(trainings), "Records within your current scope"),
      summary_card(
        "In workflow",
        Enum.count(
          trainings,
          &(&1.status in [:draft, :pending_division_approval, :pending_region_approval])
        ),
        "Draft or approval-stage activities"
      ),
      summary_card(
        "Published",
        Enum.count(trainings, &(&1.status in [:published, :registration_closed, :in_progress])),
        "Currently active for delivery or registration"
      ),
      summary_card(
        "Completed",
        Enum.count(trainings, &(&1.status in [:completed, :archived])),
        "Finished or archived activities"
      )
    ]
  end

  defp managed_training_caption(trainings) do
    count = length(trainings)
    "Showing #{count} managed training #{if(count == 1, do: "activity", else: "activities")}."
  end

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> "green"
      status in [:draft, :pending_division_approval, :pending_region_approval] -> "amber"
      status in [:completed, :archived] -> "blue"
      true -> "slate"
    end
  end
end
