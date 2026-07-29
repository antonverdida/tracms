defmodule TracmsWeb.CertificateComponents do
  @moduledoc """
  Shared certificate presentation components.
  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: TracmsWeb.Endpoint,
    router: TracmsWeb.Router,
    statics: TracmsWeb.static_paths()

  alias Tracms.Certificates

  import TracmsWeb.CoreComponents, only: [icon: 1]
  import TracmsWeb.PortalHelpers, only: [format_date: 1]

  attr :certificate, :map, required: true
  attr :participant_name, :string, required: true
  attr :issued_by_name, :string, required: true
  attr :scope_label, :string, default: nil
  attr :layout_settings, :map, default: nil

  def certificate_sheet(assigns) do
    assigns =
      assign(
        assigns,
        :layout_settings,
        assigns.layout_settings || Certificates.effective_layout_settings(assigns.certificate)
      )
      |> assign(:certificate_verification_url, certificate_verification_url(assigns.certificate))
      |> assign(:custom_asset_path, certificate_asset_image_path(assigns.layout_settings))
      |> assign(:certificate_qr_data_uri, certificate_qr_data_uri(assigns.certificate))

    ~H"""
    <article
      class={[
        "certificate-sheet",
        "certificate-sheet-size-#{certificate_size(@layout_settings)}",
        "certificate-sheet-#{certificate_layout_style(@layout_settings)}",
        @custom_asset_path && "certificate-sheet-has-custom-art",
        @custom_asset_path && "certificate-sheet-custom-layout"
      ]}
      style={certificate_css_vars(@layout_settings)}
    >
      <%= if @custom_asset_path do %>
        <div class="certificate-sheet-custom-visual">
          <img
            src={@custom_asset_path}
            alt="Uploaded certificate layout"
            class="certificate-sheet-custom-image"
          />
          <div class={[
            "certificate-sheet-custom-nameplate",
            custom_nameplate_fit_class(@participant_name)
          ]}>
            <p class={["certificate-sheet-custom-name", custom_name_size_class(@participant_name)]}>
              {@participant_name}
            </p>
          </div>

          <a
            :if={@certificate_qr_data_uri}
            href={@certificate_verification_url}
            target="_blank"
            rel="noopener noreferrer"
            class="certificate-sheet-custom-qr-card"
          >
            <img
              src={@certificate_qr_data_uri}
              alt={"QR code for certificate #{@certificate.certificate_number}"}
              class="certificate-sheet-custom-qr-image"
            />
            <div class="certificate-sheet-custom-qr-copy">
              <p class="certificate-sheet-custom-qr-label">Certificate No.</p>
              <p class="certificate-sheet-custom-qr-value">{@certificate.certificate_number}</p>
            </div>
          </a>
        </div>
      <% else %>
        <div class="certificate-sheet-inner">
          <header class="certificate-sheet-header">
            <div class="certificate-brand-block">
              <img
                src={~p"/images/tracms-region-ix-logo.png"}
                alt="TRACMS Region IX logo"
                class="certificate-brand-logo"
              />
              <div>
                <p class="certificate-brand-eyebrow">{@layout_settings.header_title}</p>
                <h1 class="certificate-brand-title">{@layout_settings.header_subtitle}</h1>
                <p class="certificate-brand-copy">Official training certificate record</p>
              </div>
            </div>

            <div class="certificate-badge">
              <.icon name="hero-academic-cap" class="size-8" />
            </div>
          </header>

          <section class="certificate-hero">
            <p class="certificate-kicker">Official Training Credential</p>
            <h2 class="certificate-title">{@certificate.certificate_type}</h2>
            <p class="certificate-copy">{@layout_settings.body_intro}</p>
            <p class="certificate-participant">{@participant_name}</p>
            <p class="certificate-copy">{@layout_settings.completion_statement}</p>
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
                {effective_issuing_office(@layout_settings, @scope_label, @certificate)}
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
              <p class="certificate-signature-role">{@layout_settings.signature_label}</p>
            </div>

            <div class="certificate-meta-block">
              <p class="certificate-meta-label">Record Status</p>
              <p class="certificate-meta-value">{certificate_status(@certificate.delivery_status)}</p>
            </div>
          </footer>
        </div>
      <% end %>
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

  defp certificate_layout_style(%{layout_style: layout_style})
       when layout_style in ["classic", "formal", "modern"] do
    layout_style
  end

  defp certificate_layout_style(_layout_settings), do: "classic"

  defp certificate_css_vars(layout_settings) do
    palette = accent_palette(Map.get(layout_settings, :accent_color))
    size = certificate_size_vars(Map.get(layout_settings, :certificate_size))

    palette
    |> Map.merge(size)
    |> Enum.map_join("; ", fn {key, value} -> "--#{key}: #{value}" end)
  end

  defp certificate_size(%{certificate_size: certificate_size})
       when certificate_size in ["a4_landscape", "letter_landscape", "legal_landscape"] do
    certificate_size
  end

  defp certificate_size(_layout_settings), do: "a4_landscape"

  defp accent_palette("blue_gold") do
    %{
      "certificate-primary" => "#0d3f7a",
      "certificate-primary-strong" => "#0b2f59",
      "certificate-accent" => "#d89a12",
      "certificate-accent-soft" => "rgba(216, 154, 18, 0.16)",
      "certificate-surface-top" => "rgba(233, 242, 255, 0.74)",
      "certificate-surface-bottom" => "rgba(255, 255, 255, 0.98)"
    }
  end

  defp accent_palette("slate_blue") do
    %{
      "certificate-primary" => "#325577",
      "certificate-primary-strong" => "#20364d",
      "certificate-accent" => "#6d89a6",
      "certificate-accent-soft" => "rgba(109, 137, 166, 0.18)",
      "certificate-surface-top" => "rgba(239, 245, 250, 0.82)",
      "certificate-surface-bottom" => "rgba(255, 255, 255, 0.98)"
    }
  end

  defp accent_palette(_accent_color) do
    %{
      "certificate-primary" => "#003366",
      "certificate-primary-strong" => "#0f2747",
      "certificate-accent" => "#c69214",
      "certificate-accent-soft" => "rgba(198, 146, 20, 0.16)",
      "certificate-surface-top" => "rgba(234, 243, 255, 0.72)",
      "certificate-surface-bottom" => "rgba(255, 255, 255, 0.98)"
    }
  end

  defp certificate_size_vars("letter_landscape") do
    %{
      "certificate-sheet-max-width" => "68rem",
      "certificate-sheet-aspect-ratio" => "11 / 8.5"
    }
  end

  defp certificate_size_vars("legal_landscape") do
    %{
      "certificate-sheet-max-width" => "78rem",
      "certificate-sheet-aspect-ratio" => "14 / 8.5"
    }
  end

  defp certificate_size_vars(_certificate_size) do
    %{
      "certificate-sheet-max-width" => "72rem",
      "certificate-sheet-aspect-ratio" => "1.414 / 1"
    }
  end

  defp effective_issuing_office(layout_settings, scope_label, certificate) do
    Map.get(layout_settings, :issuing_office_label) ||
      scope_label ||
      certificate_scope_label(certificate)
  end

  defp certificate_asset_image_path(layout_settings) do
    asset_path = Map.get(layout_settings, :asset_path)
    asset_content_type = Map.get(layout_settings, :asset_content_type)

    if certificate_image_asset?(asset_path, asset_content_type) do
      asset_path
    end
  end

  defp certificate_verification_url(%{certificate_number: certificate_number})
       when is_binary(certificate_number) and certificate_number != "" do
    url(~p"/verify/certificates/#{certificate_number}")
  end

  defp certificate_verification_url(_certificate), do: nil

  defp certificate_qr_data_uri(certificate) do
    case certificate_verification_url(certificate) do
      verification_url when is_binary(verification_url) and verification_url != "" ->
        verification_url
        |> EQRCode.encode()
        |> EQRCode.svg(%{width: 220})
        |> then(&("data:image/svg+xml;base64," <> Base.encode64(&1)))

      _verification_url ->
        nil
    end
  end

  defp custom_name_size_class(participant_name) do
    length =
      participant_name
      |> to_string()
      |> String.trim()
      |> String.length()

    cond do
      length >= 60 -> "certificate-sheet-custom-name-ultra-long"
      length >= 44 -> "certificate-sheet-custom-name-very-long"
      length >= 30 -> "certificate-sheet-custom-name-long"
      true -> "certificate-sheet-custom-name-standard"
    end
  end

  defp custom_nameplate_fit_class(participant_name) do
    length =
      participant_name
      |> to_string()
      |> String.trim()
      |> String.length()

    cond do
      length >= 60 -> "certificate-sheet-custom-nameplate-ultra-long"
      length >= 44 -> "certificate-sheet-custom-nameplate-very-long"
      length >= 30 -> "certificate-sheet-custom-nameplate-long"
      true -> "certificate-sheet-custom-nameplate-standard"
    end
  end

  defp certificate_image_asset?(asset_path, asset_content_type) do
    resolved_content_type =
      case asset_content_type do
        value when is_binary(value) and value != "" -> value
        _value when is_binary(asset_path) -> MIME.from_path(asset_path)
        _value -> nil
      end

    is_binary(asset_path) and asset_path != "" and
      is_binary(resolved_content_type) and String.starts_with?(resolved_content_type, "image/")
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
