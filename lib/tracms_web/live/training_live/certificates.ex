defmodule TracmsWeb.TrainingLive.Certificates do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Certificates")
     |> assign(:training_id, training_id)
     |> assign(:search_query, "")
     |> assign(:search_form, search_form(""))
     |> load_page()}
  end

  @impl true
  def handle_event("filter_certificates", %{"certificate_search" => %{"query" => query}}, socket) do
    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:search_form, search_form(query))
     |> assign_filtered_certificates()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="certificates"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Certificates"
          title={@training_activity.title}
          copy="Review participant certificates for this training."
        >
          <:actions>
            <.button navigate={~p"/certificates"} variant="ghost">
              Back to certificates
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/completion"} variant="ghost">
              Completion
            </.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <%= if @all_certificates == [] do %>
            <.portal_empty_state
              icon="hero-document-text"
              title="No certificates issued yet"
              copy="Participant certificates will appear here once records are issued for this training."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Participant certificates"
              title="Certificate List"
            >
              <:actions>
                <div class="flex w-full flex-col gap-3 md:w-auto md:flex-row md:items-center">
                  <.form
                    for={@search_form}
                    id="certificate-search-form"
                    phx-change="filter_certificates"
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

                  <.button
                    href={~p"/certificates/trainings/#{@training_activity.id}/download-all"}
                    variant="secondary"
                  >
                    <.icon name="hero-arrow-down-tray" class="size-5" />
                    <span>Download All Certificates</span>
                  </.button>
                </div>
              </:actions>
            </.portal_panel_header>

            <%= if @certificates == [] do %>
              <div class="portal-empty-quiet">
                <p class="section-copy">
                  No participant certificate matches your search.
                </p>
              </div>
            <% else %>
              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>Training Modality</th>
                      <th>Certificate</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={certificate <- @certificates}>
                      <td>
                        <div class="portal-cell-title">
                          {participant_name(certificate.registration)}
                        </div>
                        <div class="portal-cell-meta">
                          {certificate.registration.registrant_user.email}
                        </div>
                      </td>
                      <td>
                        {format_modality(certificate.registration.training_activity.modality)}
                      </td>
                      <td>
                        <.button
                          navigate={
                            ~p"/certificates/trainings/#{@training_activity.id}/#{certificate.id}"
                          }
                          variant="secondary"
                        >
                          View Certificate
                        </.button>
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

  defp load_page(socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, socket.assigns.training_id)

    certificates =
      Certificates.list_training_certificates(socket.assigns.current_scope, training_activity.id)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:all_certificates, certificates)
    |> assign_filtered_certificates()
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp assign_filtered_certificates(socket) do
    certificates =
      filter_certificates(
        socket.assigns.all_certificates || [],
        socket.assigns.search_query || ""
      )

    assign(socket, :certificates, certificates)
  end

  defp filter_certificates(certificates, query) do
    normalized_query =
      query
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if normalized_query == "" do
      certificates
    else
      Enum.filter(certificates, fn certificate ->
        certificate.registration
        |> participant_name()
        |> String.downcase()
        |> String.contains?(normalized_query)
      end)
    end
  end

  defp search_form(query) do
    to_form(%{"query" => query}, as: :certificate_search)
  end
end
