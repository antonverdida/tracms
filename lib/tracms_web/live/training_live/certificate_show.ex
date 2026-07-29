defmodule TracmsWeb.TrainingLive.CertificateShow do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Trainings
  alias TracmsWeb.CertificateComponents

  @impl true
  def mount(%{"training_id" => training_id, "certificate_id" => certificate_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Certificate Preview")
     |> assign(:training_id, training_id)
     |> assign(:certificate_id, certificate_id)
     |> load_page()}
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
          eyebrow="Certificate preview"
          title={@training_activity.title}
          copy="Operational preview of the issued certificate record for verification and review."
        >
          <:actions>
            <.button navigate={~p"/certificates/trainings/#{@training_activity.id}"} variant="ghost">
              Back to Certificates List
            </.button>
            <.button
              href={~p"/certificates/trainings/#{@training_activity.id}/#{@certificate.id}/print"}
              target="_blank"
              rel="noopener"
              variant="secondary"
            >
              Print certificate
            </.button>
            <.button
              href={~p"/certificates/trainings/#{@training_activity.id}/#{@certificate.id}/export"}
              variant="primary"
            >
              Export document
            </.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Issued certificate"
            title={@certificate.certificate_type}
            meta={"Certificate No. #{@certificate.certificate_number}"}
          />

          <.certificate_sheet
            certificate={@certificate}
            participant_name={CertificateComponents.certificate_participant_name(@certificate)}
            issued_by_name={CertificateComponents.certificate_issued_by_name(@certificate)}
            layout_settings={@layout_settings}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, socket.assigns.training_id)

    case Certificates.get_training_certificate(
           socket.assigns.current_scope,
           training_activity.id,
           socket.assigns.certificate_id
         ) do
      nil ->
        raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord

      certificate ->
        socket
        |> assign(:training_activity, training_activity)
        |> assign(:certificate, certificate)
        |> assign(:layout_settings, Certificates.effective_layout_settings(certificate))
    end
  end
end
