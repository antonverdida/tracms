defmodule TracmsWeb.CertificateLive.MyIndex do
  use TracmsWeb, :live_view

  alias Tracms.Certificates

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "My Certificates")
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
            <.portal_empty_state
              icon="hero-document-check"
              title="No certificates available yet"
              copy="Certificates will appear here once your completed training records are issued by the authorized office."
            />
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
                      <.button navigate={~p"/my/certificates/#{certificate.id}"} variant="secondary">
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
    </Layouts.app>
    """
  end

  defp load_certificates(socket) do
    certificates = Certificates.list_user_certificates(socket.assigns.current_scope)

    socket
    |> assign(:certificates, certificates)
    |> assign(:summary_cards, summary_cards(certificates))
  end

  defp summary_cards(certificates) do
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

  defp delivery_status_tone(:downloaded), do: "green"
  defp delivery_status_tone(:emailed), do: "blue"
  defp delivery_status_tone(:available), do: "amber"
  defp delivery_status_tone(_status), do: "slate"
end
