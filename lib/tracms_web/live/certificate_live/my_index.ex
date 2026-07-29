defmodule TracmsWeb.CertificateLive.MyIndex do
  use TracmsWeb, :live_view

  alias Tracms.Accounts.Scope
  alias Tracms.Certificates
  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:manager_view?, Scope.training_manager?(socket.assigns.current_scope))
     |> load_certificates()}
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
      <%= if @manager_view? do %>
        <div class="portal-page-shell">
          <.portal_page_header
            eyebrow="Certificate management"
            title="Certificate Management"
            copy="Review training certificates and open each certificate register."
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
                icon="hero-document-check"
                title="No training activities available yet"
                copy="Certificate management will appear here once training activities are available in your scope."
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
                          navigate={~p"/certificates/trainings/#{training.id}"}
                          class="portal-table-link"
                        >
                          <div class="portal-cell-title">{training.title}</div>
                        </.link>
                        <div class="portal-cell-meta">{training.category}</div>
                      </td>
                      <td>{format_date(training.starts_on)}</td>
                      <td>{format_date(training.ends_on)}</td>
                      <td>
                        <div>{training.participant_count}</div>
                        <div class="portal-cell-meta">
                          {if training.participant_count == 1, do: "participant", else: "participants"}
                        </div>
                      </td>
                      <td>
                        <.button navigate={~p"/certificates/trainings/#{training.id}"}>View</.button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </section>
        </div>
      <% else %>
        <div class="portal-page-shell">
          <.portal_page_header
            eyebrow="My certificates"
            title="Issued Certificates"
            copy="Review the certificates that have already been issued under your training records."
          >
            <:actions>
              <.button navigate={~p"/my/registrations"} variant="ghost">My registrations</.button>
            </:actions>
          </.portal_page_header>

          <.portal_stat_grid cards={@summary_cards} />

          <section class="panel portal-list-panel">
            <%= if @certificates == [] do %>
              <div class="portal-panel-stack">
                <.portal_empty_state
                  icon="hero-document-check"
                  title="No certificates available yet"
                  copy="Certificates will appear here once your completed training records are issued by the authorized office."
                />

                <div class="certificate-sample-shell">
                  <.portal_panel_header
                    eyebrow="Sample preview"
                    title="Demo Certificate"
                    meta="Reference layout shown until the first real certificate record is issued."
                  />

                  <.certificate_sheet
                    certificate={@sample_certificate}
                    participant_name="TRACMS Administrator"
                    issued_by_name="DepEd Region IX Training Office"
                    scope_label="DepEd Region IX"
                  />
                </div>
              </div>
            <% else %>
              <.portal_panel_header
                eyebrow="Issued records"
                title="Certificate History"
                meta={certificate_caption(@certificates)}
              />

              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Training</th>
                      <th>Certificate Number</th>
                      <th>Type</th>
                      <th>Issued On</th>
                      <th>Status</th>
                      <th>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={certificate <- @certificates}>
                      <td>
                        <div class="portal-cell-title">
                          {certificate.registration.training_activity.title}
                        </div>
                        <div class="portal-cell-meta">
                          {format_date(certificate.registration.training_activity.starts_on)} to {format_date(
                            certificate.registration.training_activity.ends_on
                          )}
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
                      <td>
                        <.button navigate={~p"/certificates/#{certificate.id}"} variant="secondary">
                          View certificate
                        </.button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </section>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp load_certificates(socket) do
    if socket.assigns.manager_view? do
      load_manager_certificates(socket)
    else
      load_participant_certificates(socket)
    end
  end

  defp load_participant_certificates(socket) do
    certificates = Certificates.list_user_certificates(socket.assigns.current_scope)

    socket
    |> assign(:page_title, "My Certificates")
    |> assign(:sample_certificate, Certificates.sample_preview_certificate())
    |> assign(:certificates, certificates)
    |> assign(:summary_cards, participant_summary_cards(certificates))
  end

  defp load_manager_certificates(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)
    training_activities = manager_training_cards(socket, trainings)

    socket
    |> assign(:page_title, "Certificate Management")
    |> assign(:training_activities, training_activities)
    |> assign(:training_caption, training_caption(training_activities))
  end

  defp participant_summary_cards(certificates) do
    [
      summary_card("Issued", length(certificates), "Total certificate records on file"),
      summary_card(
        "Available",
        Enum.count(certificates, &(&1.delivery_status == :available)),
        "Ready for participant acknowledgement"
      ),
      summary_card(
        "Downloaded",
        Enum.count(certificates, &(&1.delivery_status == :downloaded)),
        "Acknowledged by the participant"
      ),
      summary_card(
        "Emailed",
        Enum.count(certificates, &(&1.delivery_status == :emailed)),
        "Reserved for future release workflow"
      )
    ]
  end

  defp certificate_caption(certificates) do
    count = length(certificates)
    "Showing #{count} issued certificate #{if(count == 1, do: "record", else: "records")}."
  end

  defp training_caption(training_activities) do
    count = length(training_activities)
    "Showing #{count} training #{if(count == 1, do: "activity", else: "activities")}."
  end

  defp manager_training_cards(socket, trainings) do
    Enum.map(trainings, fn training ->
      certificates =
        Certificates.list_training_certificates(socket.assigns.current_scope, training.id)

      issueable_entries =
        Certificates.list_issueable_entries(socket.assigns.current_scope, training.id)

      %{
        id: training.id,
        title: training.title,
        category: training.category || "General",
        starts_on: training.starts_on,
        ends_on: training.ends_on,
        participant_count: participant_count(certificates, issueable_entries)
      }
    end)
  end

  defp participant_count(certificates, issueable_entries) do
    certificates
    |> Enum.map(fn certificate -> participant_name(certificate.registration) end)
    |> Kernel.++(Enum.map(issueable_entries, &participant_name(&1.registration)))
    |> Enum.uniq()
    |> length()
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp delivery_status_tone(:downloaded), do: "green"
  defp delivery_status_tone(:emailed), do: "blue"
  defp delivery_status_tone(:available), do: "amber"
  defp delivery_status_tone(_status), do: "slate"
end
