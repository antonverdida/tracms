defmodule TracmsWeb.TrainingLive.CertificateShow do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
  alias Tracms.Trainings

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
      active_nav="trainings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Certificate preview"
          title={@training_activity.title}
          copy="Operational preview of the issued certificate record for verification and review."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}/certificates"} variant="ghost">
              Back to certificate register
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
            participant_name={participant_name(@certificate)}
            issued_by_name={issued_by_name(@certificate)}
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
