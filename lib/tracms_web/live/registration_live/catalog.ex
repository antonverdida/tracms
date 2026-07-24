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
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="catalog"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Registration"
          title="Available Trainings"
          copy="Browse published training activities that are currently open for registration."
        >
          <:actions>
            <.button navigate={~p"/my/registrations"} variant="ghost">My records</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <%= if @training_activities == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-book-open"
              title="No open trainings available"
              copy="Published trainings with active registration windows will appear here."
            />
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Published activities"
              title="Open registration catalog"
              meta={@catalog_caption}
            />

            <div class="portal-resource-grid">
              <article :for={training <- @training_activities} class="portal-resource-card">
                <div class="portal-resource-head">
                  <div>
                    <h2 class="portal-resource-title">{training.title}</h2>
                    <p class="portal-resource-copy">{training.description}</p>
                  </div>
                </div>

                <div class="badge-row">
                  <span class="badge-soft">{training.category}</span>
                  <span class="badge-soft">{format_date(training.starts_on)}</span>
                  <span class="badge-soft">{format_modality(training.modality)}</span>
                  <span class="badge-soft">{registration_mode_label(training)}</span>
                </div>

                <div class="portal-resource-facts">
                  <div>
                    <span class="portal-fact-label">Venue</span>
                    <span class="portal-fact-value">{training.venue}</span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Schedule</span>
                    <span class="portal-fact-value">
                      {format_date(training.starts_on)} to {format_date(training.ends_on)}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Deadline</span>
                    <span class="portal-fact-value">
                      {format_datetime(training.registration_deadline)}
                    </span>
                  </div>
                  <div>
                    <span class="portal-fact-label">Capacity</span>
                    <span class="portal-fact-value">{training.max_capacity}</span>
                  </div>
                </div>

                <div class="portal-resource-footer">
                  <span class={["portal-chip", "portal-chip-#{status_tone(training.status)}"]}>
                    {Registrations.format_status(training.status)}
                  </span>
                  <.button navigate={~p"/catalog/trainings/#{training.id}"}>View details</.button>
                </div>
              </article>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_catalog(socket) do
    training_activities =
      Registrations.list_open_training_activities(socket.assigns.current_scope)

    socket
    |> assign(:training_activities, training_activities)
    |> assign(:summary_cards, catalog_summary_cards(training_activities))
    |> assign(:catalog_caption, catalog_caption(training_activities))
  end

  defp catalog_summary_cards(training_activities) do
    today = Date.utc_today()

    [
      summary_card(
        "Open trainings",
        length(training_activities),
        "Published activities you can register for"
      ),
      summary_card(
        "Starting soon",
        Enum.count(training_activities, fn training ->
          training.starts_on && Date.diff(training.starts_on, today) in 0..30
        end),
        "Activities beginning within the next 30 days"
      ),
      summary_card(
        "Categories",
        training_activities |> Enum.map(& &1.category) |> Enum.uniq() |> length(),
        "Distinct activity categories currently available"
      ),
      summary_card(
        "Online or hybrid",
        Enum.count(training_activities, &(&1.modality in [:online, :hybrid])),
        "Activities with online participation options"
      )
    ]
  end

  defp catalog_caption(training_activities) do
    count = length(training_activities)
    "Showing #{count} open training #{if(count == 1, do: "activity", else: "activities")}."
  end

  defp status_tone(:published), do: "green"
  defp status_tone(:registration_closed), do: "amber"
  defp status_tone(_status), do: "blue"

  defp registration_mode_label(%{registration_form_url: nil}), do: "TRACMS registration"
  defp registration_mode_label(_training), do: "External registration"
end
