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
     |> load_page()}
  end

  @impl true
  def handle_event("issue", %{"registration_id" => registration_id}, socket) do
    case Certificates.issue_certificate(socket.assigns.current_scope, registration_id) do
      {:ok, _certificate} ->
        {:noreply,
         socket
         |> put_flash(:info, "Certificate issued successfully.")
         |> load_page()}

      {:error, :already_issued} ->
        {:noreply,
         put_flash(socket, :error, "A certificate was already issued for this participant.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You cannot issue a certificate for this record.")}

      {:error, :registration_not_found} ->
        {:noreply, put_flash(socket, :error, "The selected registration could not be found.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Certificate issuance could not be completed.")}
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
          eyebrow="Certificates"
          title={@training_activity.title}
          copy="Issue certificates to completion-ready participants and monitor certificate release records."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/completion"} variant="ghost">
              Completion
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="panel portal-list-panel">
          <%= if @issueable_entries == [] do %>
            <.portal_empty_state
              icon="hero-academic-cap"
              title="No participants ready for issuance"
              copy="Certificates can be issued after the participant satisfies attendance and evaluation requirements."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Ready to issue"
              title="Completion-ready participants"
              meta={issueable_caption(@issueable_entries)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Attendance</th>
                    <th>Evaluation</th>
                    <th>Certificate Type</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @issueable_entries}>
                    <td>
                      <div class="portal-cell-title">{participant_name(entry.registration)}</div>
                      <div class="portal-cell-meta">{entry.registration.registrant_user.email}</div>
                    </td>
                    <td>
                      <div>{entry.attendance_percentage}%</div>
                      <div class="portal-cell-meta">
                        {entry.attended_sessions_count} of {entry.total_sessions_count} sessions
                      </div>
                    </td>
                    <td>{evaluation_label(@training_activity.evaluation_required, entry)}</td>
                    <td>{@training_activity.certificate_type}</td>
                    <td>
                      <.button phx-click="issue" phx-value-registration_id={entry.registration.id}>
                        Issue certificate
                      </.button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <section class="panel portal-list-panel">
          <%= if @certificates == [] do %>
            <.portal_empty_state
              icon="hero-document-text"
              title="No certificates issued yet"
              copy="Issued certificates for this training will appear here once completion-ready participants are processed."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Issued records"
              title="Certificate Register"
              meta={certificate_caption(@certificates)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Certificate Number</th>
                    <th>Type</th>
                    <th>Issued On</th>
                    <th>Status</th>
                    <th>Issued By</th>
                    <th>Action</th>
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
                    <td>{certificate.certificate_number}</td>
                    <td>{certificate.certificate_type}</td>
                    <td>{format_date(certificate.issued_on)}</td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{delivery_status_tone(certificate.delivery_status)}"
                      ]}>
                        {Certificates.format_delivery_status(certificate.delivery_status)}
                      </span>
                    </td>
                    <td>{issued_by_name(certificate)}</td>
                    <td>
                      <.button
                        navigate={
                          ~p"/trainings/#{@training_activity.id}/certificates/#{certificate.id}"
                        }
                        variant="secondary"
                      >
                        Preview
                      </.button>
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

  defp load_page(socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, socket.assigns.training_id)

    certificates =
      Certificates.list_training_certificates(socket.assigns.current_scope, training_activity.id)

    issueable_entries =
      Certificates.list_issueable_entries(socket.assigns.current_scope, training_activity.id)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:certificates, certificates)
    |> assign(:issueable_entries, issueable_entries)
    |> assign(:summary_cards, summary_cards(certificates, issueable_entries))
  end

  defp summary_cards(certificates, issueable_entries) do
    [
      summary_card(
        "Issued",
        length(certificates),
        "Certificate records generated for this training"
      ),
      summary_card(
        "Ready to issue",
        length(issueable_entries),
        "Completion-ready participants awaiting release"
      ),
      summary_card(
        "Downloaded",
        Enum.count(certificates, &(&1.delivery_status == :downloaded)),
        "Participants who already acknowledged access"
      ),
      summary_card(
        "Available",
        Enum.count(certificates, &(&1.delivery_status == :available)),
        "Issued records not yet acknowledged"
      )
    ]
  end

  defp issueable_caption(entries) do
    count = length(entries)

    "Showing #{count} completion-ready participant #{if(count == 1, do: "record", else: "records")}."
  end

  defp certificate_caption(certificates) do
    count = length(certificates)
    "Showing #{count} issued certificate #{if(count == 1, do: "record", else: "records")}."
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp evaluation_label(false, _entry), do: "Not required"
  defp evaluation_label(true, %{evaluation_submission: nil}), do: "Pending"
  defp evaluation_label(true, _entry), do: "Submitted"

  defp issued_by_name(%{issued_by_user: %{full_name: full_name, email: email}}) do
    full_name || email
  end

  defp issued_by_name(_certificate), do: "System"

  defp delivery_status_tone(:downloaded), do: "green"
  defp delivery_status_tone(:emailed), do: "blue"
  defp delivery_status_tone(:available), do: "amber"
  defp delivery_status_tone(_status), do: "slate"
end
