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
        !@custom_asset_path && "certificate-sheet-upload-required",
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
            class="certificate-sheet-custom-qr"
          >
            <img
              src={@certificate_qr_data_uri}
              alt={"QR code for certificate #{@certificate.certificate_number}"}
              class="certificate-sheet-custom-qr-image"
            />
          </a>
        </div>
      <% else %>
        <div class="certificate-layout-empty-state">
          <div class="certificate-layout-empty-icon">
            <.icon name="hero-photo" class="size-8" />
          </div>

          <div class="certificate-layout-empty-copy">
            <p class="certificate-layout-empty-eyebrow">Upload Required</p>
            <h2 class="certificate-layout-empty-title">No certificate layout uploaded yet</h2>
            <p class="certificate-layout-empty-text">
              Upload a certificate layout image in Settings so certificate preview, PDF download,
              and print output use your official design instead of a hardcoded template.
            </p>
          </div>

          <div class="certificate-layout-empty-meta">
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Participant Name</p>
              <p class="certificate-layout-empty-value">{@participant_name}</p>
            </div>
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Training Title</p>
              <p class="certificate-layout-empty-value">
                {@certificate.registration.training_activity.title}
              </p>
            </div>
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Training Date</p>
              <p class="certificate-layout-empty-value">
                {format_date(@certificate.registration.training_activity.starts_on)} to {format_date(
                  @certificate.registration.training_activity.ends_on
                )}
              </p>
            </div>
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Venue</p>
              <p class="certificate-layout-empty-value">
                {@certificate.registration.training_activity.venue || "Venue to be announced"}
              </p>
            </div>
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Certificate Number</p>
              <p class="certificate-layout-empty-value">{@certificate.certificate_number}</p>
            </div>
            <div class="certificate-layout-empty-card">
              <p class="certificate-layout-empty-label">Facilitator or Signatory</p>
              <p class="certificate-layout-empty-value">{@issued_by_name}</p>
            </div>
          </div>
        </div>
      <% end %>
    </article>
    """
  end

  def certificate_participant_name(%{registration: registration}),
    do: Tracms.Registrations.participant_name(registration)

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
    |> Map.put(
      "certificate-participant-name-top",
      "#{participant_name_position(layout_settings)}%"
    )
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

  defp certificate_asset_image_path(layout_settings) do
    asset_data = Map.get(layout_settings, :asset_data)
    asset_path = Map.get(layout_settings, :asset_path)
    asset_content_type = Map.get(layout_settings, :asset_content_type)

    cond do
      is_binary(asset_data) and byte_size(asset_data) > 0 and is_binary(asset_content_type) ->
        "data:#{asset_content_type};base64," <> Base.encode64(asset_data)

      certificate_image_asset?(asset_path, asset_content_type) ->
        asset_path

      true ->
        nil
    end
  end

  defp participant_name_position(%{participant_name_position: position})
       when is_number(position) and position >= 15 and position <= 75,
       do: position

  defp participant_name_position(_layout_settings), do: 39.0

  defp certificate_verification_url(%{verification_code: verification_code})
       when is_binary(verification_code) and verification_code != "" do
    url(~p"/verify/certificates/scan/#{verification_code}")
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
end
