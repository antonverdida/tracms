defmodule TracmsWeb.TrainingLive.RegistrationManagement do
  use TracmsWeb, :live_view

  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Registration Management")
     |> load_registration_dashboard()}
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
          eyebrow="Registration management"
          title="Registration Management"
          copy="Review training registrations and open each registration register."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Training management</.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Current records"
            title="Managed Trainings"
            meta={@training_caption}
          />

          <%= if @training_activities == [] do %>
            <.portal_empty_state
              icon="hero-user-group"
              title="No training activities available yet"
              copy="Registration management will appear here once training activities are available in your scope."
            />
          <% else %>
            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Training</th>
                    <th>Start Date</th>
                    <th>End Date</th>
                    <th>Participants</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={training <- @training_activities}>
                    <td>
                      <.link
                        navigate={~p"/registrations/trainings/#{training.id}"}
                        class="portal-table-link"
                      >
                        <div class="portal-cell-title">{training.title}</div>
                      </.link>
                      <div class="portal-cell-meta">
                        {training.category}
                        <%= if training.external_workflow do %>
                          <span> • External intake</span>
                        <% end %>
                      </div>
                    </td>
                    <td>{format_date(training.starts_on)}</td>
                    <td>{format_date(training.ends_on)}</td>
                    <td>
                      <div>{training.registration_count}</div>
                    </td>
                    <td>
                      <.button navigate={~p"/registrations/trainings/#{training.id}"}>View</.button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_registration_dashboard(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)
    training_activities = training_activity_cards(socket, trainings)

    socket
    |> assign(:training_activities, training_activities)
    |> assign(:training_caption, registration_caption(training_activities))
  end

  defp registration_caption(training_activities) do
    count = length(training_activities)
    "Showing #{count} training #{if(count == 1, do: "activity", else: "activities")}."
  end

  defp training_activity_cards(socket, trainings) do
    Enum.map(trainings, fn training ->
      registrations =
        Registrations.list_training_registrations(socket.assigns.current_scope, training.id)

      external_submissions =
        if external_workflow?(training),
          do:
            Registrations.list_external_registration_submissions(
              socket.assigns.current_scope,
              training.id
            ),
          else: []

      %{
        id: training.id,
        title: training.title,
        category: training.category || "General",
        starts_on: training.starts_on,
        ends_on: training.ends_on,
        registration_count: length(registrations),
        external_workflow: external_workflow?(training),
        external_submission_count: length(external_submissions)
      }
    end)
  end

  defp external_workflow?(training_activity) do
    is_binary(training_activity.registration_form_url) and
      training_activity.registration_form_url != ""
  end
end
