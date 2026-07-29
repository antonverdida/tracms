defmodule TracmsWeb.RegistrationLive.MyIndex do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Evaluations
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
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="registrations"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="My records"
          title="My Registrations"
          copy="Track the status of your submitted training registrations."
        >
          <:actions>
            <.button navigate={~p"/catalog/trainings"}>Browse trainings</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <%= if @registrations == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-identification"
              title="No registrations yet"
              copy="Once you submit a training registration, it will appear here."
            >
              <:actions>
                <.link
                  navigate={~p"/catalog/trainings"}
                  class="portal-link-button portal-link-button-primary"
                >
                  Browse trainings
                </.link>
              </:actions>
            </.portal_empty_state>
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Submitted records"
              title="Registration History"
              meta={@registration_caption}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Training</th>
                    <th>Submitted</th>
                    <th>Status</th>
                    <th>Evaluation</th>
                    <th>Certificate</th>
                    <th>Notes</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={registration <- @registrations}>
                    <td>
                      <div class="portal-cell-title">{registration.training_activity.title}</div>
                      <div class="portal-cell-meta">
                        {format_date(registration.training_activity.starts_on)} to {format_date(
                          registration.training_activity.ends_on
                        )}
                      </div>
                    </td>
                    <td>{format_datetime(registration.submitted_at)}</td>
                    <td>
                      <span class={["portal-chip", "portal-chip-#{status_tone(registration.status)}"]}>
                        {Registrations.format_status(registration.status)}
                      </span>
                    </td>
                    <td>{evaluation_status_label(registration, @evaluation_submissions)}</td>
                    <td>
                      {certificate_label(Map.get(@certificate_map, registration.id), registration)}
                    </td>
                    <td>{registration.review_notes || "No review notes yet"}</td>
                    <td>
                      <div class="portal-action-stack">
                        <.button
                          navigate={~p"/catalog/trainings/#{registration.training_activity.id}"}
                          variant="secondary"
                        >
                          View training
                        </.button>
                        <.button
                          :if={
                            registration.status == :approved and
                              registration.training_activity.evaluation_required
                          }
                          navigate={~p"/my/registrations/#{registration.id}/evaluation"}
                          variant="secondary"
                        >
                          {evaluation_action_label(registration, @evaluation_submissions)}
                        </.button>
                        <.button
                          :if={certificate = Map.get(@certificate_map, registration.id)}
                          navigate={~p"/certificates/#{certificate.id}"}
                          variant="secondary"
                        >
                          View certificate
                        </.button>
                        <.button
                          :if={registration.status in [:submitted, :approved, :waitlisted]}
                          phx-click="withdraw"
                          phx-value-id={registration.id}
                          variant="ghost"
                        >
                          Withdraw
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
    registrations = Registrations.list_user_registrations(socket.assigns.current_scope)
    evaluation_submissions = Evaluations.list_submission_map(Enum.map(registrations, & &1.id))

    certificate_map =
      Certificates.list_certificate_map_for_registrations(Enum.map(registrations, & &1.id))

    socket
    |> assign(:registrations, registrations)
    |> assign(:evaluation_submissions, evaluation_submissions)
    |> assign(:certificate_map, certificate_map)
    |> assign(
      :summary_cards,
      registration_summary_cards(registrations, evaluation_submissions, certificate_map)
    )
    |> assign(:registration_caption, registration_caption(registrations))
  end

  defp registration_summary_cards(registrations, evaluation_submissions, certificate_map) do
    [
      summary_card("Total records", length(registrations), "Submitted training registrations"),
      summary_card(
        "Approved",
        Enum.count(registrations, &(&1.status == :approved)),
        "Registrations confirmed for participation"
      ),
      summary_card(
        "Awaiting update",
        Enum.count(registrations, &(&1.status in [:submitted, :waitlisted])),
        "Submitted or waitlisted records"
      ),
      summary_card(
        "Certificates issued",
        map_size(certificate_map),
        "Training records with released certificates"
      ),
      summary_card(
        "Evaluation pending",
        Enum.count(registrations, fn registration ->
          registration.status == :approved and
            registration.training_activity.evaluation_required and
            not Map.has_key?(evaluation_submissions, registration.id)
        end),
        "Approved trainings that require evaluation"
      )
    ]
  end

  defp registration_caption(registrations) do
    count = length(registrations)
    "Showing #{count} registration #{if(count == 1, do: "record", else: "records")}."
  end

  defp evaluation_status_label(registration, evaluation_submissions) do
    cond do
      not registration.training_activity.evaluation_required ->
        "Not required"

      Map.has_key?(evaluation_submissions, registration.id) ->
        "Submitted"

      true ->
        "Pending"
    end
  end

  defp evaluation_action_label(registration, evaluation_submissions) do
    if Map.has_key?(evaluation_submissions, registration.id) do
      "Update evaluation"
    else
      "Submit evaluation"
    end
  end

  defp certificate_label(nil, %{status: :approved}), do: "Awaiting issuance"
  defp certificate_label(nil, _registration), do: "Not available"

  defp certificate_label(certificate, _registration) do
    "#{Certificates.format_delivery_status(certificate.delivery_status)} • #{certificate.certificate_number}"
  end

  defp status_tone(:approved), do: "green"
  defp status_tone(:submitted), do: "blue"
  defp status_tone(:waitlisted), do: "amber"
  defp status_tone(:rejected), do: "rose"
  defp status_tone(:withdrawn), do: "slate"
  defp status_tone(_status), do: "slate"
end
