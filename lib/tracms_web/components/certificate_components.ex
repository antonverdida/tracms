defmodule TracmsWeb.CertificateComponents do
  @moduledoc """
  Shared certificate presentation components.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: TracmsWeb.Endpoint,
    router: TracmsWeb.Router,
    statics: TracmsWeb.static_paths()

  import TracmsWeb.CoreComponents, only: [icon: 1]
  import TracmsWeb.PortalHelpers, only: [format_date: 1]

  attr :certificate, :map, required: true
  attr :participant_name, :string, required: true
  attr :issued_by_name, :string, required: true
  attr :scope_label, :string, default: nil

  def certificate_sheet(assigns) do
    ~H"""
    <article class="certificate-sheet">
      <div class="certificate-sheet-inner">
        <header class="certificate-sheet-header">
          <div class="certificate-brand-block">
            <img src={~p"/images/tracms-logo.svg"} alt="TRACMS logo" class="certificate-brand-logo" />
            <div>
              <p class="certificate-brand-eyebrow">Department of Education</p>
              <h1 class="certificate-brand-title">Region IX</h1>
              <p class="certificate-brand-copy">
                Training, Registration, Attendance, and Certification Management System
              </p>
            </div>
          </div>

          <div class="certificate-badge">
            <.icon name="hero-academic-cap" class="size-8" />
          </div>
        </header>

        <section class="certificate-hero">
          <p class="certificate-kicker">Official Training Credential</p>
          <h2 class="certificate-title">{@certificate.certificate_type}</h2>
          <p class="certificate-copy">This certifies that</p>
          <p class="certificate-participant">{@participant_name}</p>
          <p class="certificate-copy">
            successfully completed the authorized learning and development activity
          </p>
          <p class="certificate-training-title">
            {@certificate.registration.training_activity.title}
          </p>
        </section>

        <section class="certificate-details-grid">
          <div class="certificate-detail-card">
            <p class="certificate-detail-label">Training Schedule</p>
            <p class="certificate-detail-value">
              {format_date(@certificate.registration.training_activity.starts_on)} to {format_date(
                @certificate.registration.training_activity.ends_on
              )}
            </p>
          </div>

          <div class="certificate-detail-card">
            <p class="certificate-detail-label">Certificate Number</p>
            <p class="certificate-detail-value">{@certificate.certificate_number}</p>
          </div>

          <div class="certificate-detail-card">
            <p class="certificate-detail-label">Issued On</p>
            <p class="certificate-detail-value">{format_date(@certificate.issued_on)}</p>
          </div>

          <div class="certificate-detail-card">
            <p class="certificate-detail-label">Issuing Office</p>
            <p class="certificate-detail-value">
              {@scope_label || issuing_scope(@certificate.registration.training_activity)}
            </p>
          </div>
        </section>

        <section class="certificate-body-note">
          <p>
            This certificate record was issued through TRACMS for authorized DepEd Region IX
            training documentation and participant records management.
          </p>
        </section>

        <footer class="certificate-footer">
          <div class="certificate-signature-block">
            <div class="certificate-signature-line"></div>
            <p class="certificate-signature-name">{@issued_by_name}</p>
            <p class="certificate-signature-role">Authorized Issuing Officer</p>
          </div>

          <div class="certificate-meta-block">
            <p class="certificate-meta-label">Record Status</p>
            <p class="certificate-meta-value">{certificate_status(@certificate.delivery_status)}</p>
          </div>
        </footer>
      </div>
    </article>
    """
  end

  def certificate_participant_name(%{registration: %{registrant_user: registrant_user}}) do
    registrant_user.full_name || registrant_user.email
  end

  def certificate_issued_by_name(%{issued_by_user: %{full_name: full_name, email: email}}) do
    full_name || email
  end

  def certificate_issued_by_name(_certificate), do: "Authorized Issuing Officer"

  def certificate_scope_label(%{registration: %{training_activity: training_activity}}) do
    issuing_scope(training_activity)
  end

  defp issuing_scope(training_activity) do
    cond do
      training_activity.office && training_activity.office.name ->
        training_activity.office.name

      training_activity.division && training_activity.division.name ->
        training_activity.division.name

      true ->
        "DepEd Region IX"
    end
  end

  defp certificate_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
