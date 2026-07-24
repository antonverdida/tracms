defmodule TracmsWeb.CertificateLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Certificates

  @impl true
  def mount(%{"id" => certificate_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Certificate")
     |> assign(:certificate_id, certificate_id)
     |> load_certificate()}
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
          eyebrow="Certificate record"
          title={@certificate.registration.training_activity.title}
          copy="Official certificate view for your completed training record."
        >
          <:actions>
            <.button navigate={~p"/my/certificates"} variant="ghost">Back to certificates</.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Certificate details"
            title={@certificate.certificate_type}
            meta={"Certificate No. #{@certificate.certificate_number}"}
          />

          <.certificate_sheet
            certificate={@certificate}
            participant_name={participant_name(@certificate)}
            issued_by_name={issued_by_name(@certificate)}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_certificate(socket) do
    case Certificates.acknowledge_certificate_access(
           socket.assigns.current_scope,
           socket.assigns.certificate_id
         ) do
      {:ok, certificate} ->
        assign(socket, :certificate, certificate)

      {:error, :not_found} ->
        raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord
    end
  end

  defp participant_name(certificate) do
    certificate.registration.registrant_user.full_name ||
      certificate.registration.registrant_user.email
  end

  defp issued_by_name(%{issued_by_user: %{full_name: full_name, email: email}}) do
    full_name || email
  end

  defp issued_by_name(_certificate), do: "Authorized Issuing Officer"
end
