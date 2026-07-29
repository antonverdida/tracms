defmodule TracmsWeb.TrainingLive.RegistrationRegister do
  use TracmsWeb, :live_view

  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    registrations =
      Registrations.list_training_registrations(
        socket.assigns.current_scope,
        training_activity.id
      )

    {:ok,
     socket
     |> assign(:page_title, "Registrations")
     |> assign(:training_activity, training_activity)
     |> assign(:all_registrations, registrations)
     |> assign(:search_query, "")
     |> assign(:search_form, search_form(""))
     |> assign_filtered_registrations()}
  end

  @impl true
  def handle_event(
        "filter_registrations",
        %{"registration_search" => %{"query" => query}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_form, search_form(query))
     |> assign_filtered_registrations()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="registrations"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Registrations"
          title={@training_activity.title}
          copy="Review the registered participants for this training."
        >
          <:actions>
            <.button navigate={~p"/registrations"} variant="ghost">Back to registrations</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={[
          %{
            label: "Start Date",
            value: format_date(@training_activity.starts_on),
            meta: nil
          },
          %{
            label: "End Date",
            value: format_date(@training_activity.ends_on),
            meta: nil
          },
          %{
            label: "Total Participants",
            value: length(@all_registrations),
            meta: nil
          }
        ]} />

        <section class="panel portal-list-panel">
          <%= if @all_registrations == [] do %>
            <.portal_empty_state
              icon="hero-user-group"
              title="No participants registered yet"
              copy="Participant names will appear here once registrations are submitted for this training."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Participant records"
              title="Participant List"
            >
              <:actions>
                <.form
                  for={@search_form}
                  id="registration-search-form"
                  phx-change="filter_registrations"
                >
                  <div class="relative w-full min-w-[18rem] max-w-md">
                    <span class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-4 text-[var(--tracms-text-muted)]">
                      <.icon name="hero-magnifying-glass" class="size-5" />
                    </span>
                    <.input
                      field={@search_form[:query]}
                      type="text"
                      placeholder="Search participant name"
                      autocomplete="off"
                      class="min-h-12 w-full rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white pl-11 pr-4 text-sm text-[var(--tracms-text)] shadow-sm transition focus:border-[var(--tracms-primary)] focus:outline-none focus:ring-4 focus:ring-[color:rgba(15,74,146,0.08)]"
                    />
                  </div>
                </.form>
              </:actions>
            </.portal_panel_header>

            <%= if @registrations == [] do %>
              <div class="portal-empty-quiet">
                <p class="section-copy">
                  No participant name matches your search.
                </p>
              </div>
            <% else %>
              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>No.</th>
                      <th>Participant Name</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={{registration, index} <- Enum.with_index(@registrations, 1)}>
                      <td>{index}</td>
                      <td>
                        <div class="portal-cell-title">
                          {participant_name(registration)}
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp assign_filtered_registrations(socket) do
    registrations =
      filter_registrations(
        socket.assigns.all_registrations || [],
        socket.assigns.search_query || ""
      )

    assign(socket, :registrations, registrations)
  end

  defp filter_registrations(registrations, query) do
    normalized_query =
      query
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if normalized_query == "" do
      registrations
    else
      Enum.filter(registrations, fn registration ->
        registration
        |> participant_name()
        |> String.downcase()
        |> String.contains?(normalized_query)
      end)
    end
  end

  defp search_form(query) do
    to_form(%{"query" => query}, as: :registration_search)
  end
end
