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
          copy="Review and manage training records for DepEd Region IX."
        >
          <:actions>
            <.button navigate={~p"/trainings/new"} variant="secondary">Create training</.button>
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
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={training <- @trainings}>
                    <td>
                      <.link navigate={~p"/trainings/#{training.id}"} class="portal-table-link">
                        <div class="portal-cell-title">{training.title}</div>
                      </.link>
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
                      <.button navigate={~p"/trainings/#{training.id}"}>View</.button>
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
      summary_card("Total trainings", length(trainings), "Training records in your scope"),
      summary_card(
        "In workflow",
        Enum.count(
          trainings,
          &(&1.status in [:draft, :pending_division_approval, :pending_region_approval])
        ),
        "Draft and approval-stage records"
      ),
      summary_card(
        "Published",
        Enum.count(trainings, &(&1.status in [:published, :registration_closed, :in_progress])),
        "Open or active training records"
      ),
      summary_card(
        "Completed",
        Enum.count(trainings, &(&1.status in [:completed, :archived])),
        "Finished training records"
      )
    ]
  end

  defp managed_training_caption(trainings) do
    count = length(trainings)

    "#{count} training #{if(count == 1, do: "record", else: "records")}. Use View to open the full training details."
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
