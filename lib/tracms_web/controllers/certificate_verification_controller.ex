defmodule TracmsWeb.CertificateVerificationController do
  use TracmsWeb, :controller

  alias Tracms.Certificates
  alias TracmsWeb.CertificateComponents

  def index(conn, params) do
    case normalize_certificate_number(params["certificate_number"]) do
      nil ->
        render(conn, :index, page_title: "Certificate Verification", certificate_number: nil)

      certificate_number ->
        case Certificates.get_certificate_by_number(certificate_number) do
          nil ->
            render(conn, :index,
              page_title: "Certificate Verification",
              certificate_number: certificate_number,
              lookup_error: "No certificate record was found for that certificate number."
            )

          certificate ->
            redirect(conn, to: ~p"/verify/certificates/#{certificate.certificate_number}")
        end
    end
  end

  def show(conn, %{"certificate_number" => certificate_number}) do
    case Certificates.get_certificate_by_number(certificate_number) do
      nil ->
        conn
        |> put_status(:not_found)
        |> render(:show,
          page_title: "Certificate Not Found",
          certificate: nil,
          certificate_number: certificate_number
        )

      certificate ->
        render(conn, :show,
          page_title: "Verified Certificate Record",
          certificate: certificate,
          certificate_number: certificate.certificate_number,
          layout_settings: Certificates.effective_layout_settings(certificate),
          participant_name: CertificateComponents.certificate_participant_name(certificate),
          issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
          scope_label: CertificateComponents.certificate_scope_label(certificate)
        )
    end
  end

  defp normalize_certificate_number(certificate_number) when is_binary(certificate_number) do
    case String.trim(certificate_number) do
      "" -> nil
      normalized_number -> normalized_number
    end
  end

  defp normalize_certificate_number(_certificate_number), do: nil
end
