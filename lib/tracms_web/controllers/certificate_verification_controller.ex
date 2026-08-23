defmodule TracmsWeb.CertificateVerificationController do
  use TracmsWeb, :controller

  alias Tracms.Certificates
  alias TracmsWeb.CertificateComponents

  def index(conn, params) do
    case normalize_certificate_number(params["certificate_number"]) do
      nil ->
        render(conn, :index, page_title: "Certificate Verification", certificate_number: nil)

      certificate_number ->
        case Certificates.verify_certificate_by_number(certificate_number) do
          {:invalid, _reason} ->
            render(conn, :index,
              page_title: "Certificate Verification",
              certificate_number: certificate_number,
              lookup_error: "No certificate record was found for that certificate number."
            )

          {:valid, certificate} ->
            redirect(conn, to: ~p"/verify/certificates/#{certificate.certificate_number}")
        end
    end
  end

  def show(conn, %{"certificate_number" => certificate_number}) do
    certificate_number
    |> Certificates.verify_certificate_by_number()
    |> render_verification_result(conn, certificate_number)
  end

  def scan(conn, %{"verification_code" => verification_code}) do
    verification_code
    |> Certificates.verify_certificate_by_code()
    |> render_verification_result(conn, verification_code)
  end

  defp render_verification_result({:valid, certificate}, conn, _lookup_value) do
    render(conn, :show,
      page_title: "Verified Certificate Record",
      certificate: certificate,
      certificate_number: certificate.certificate_number,
      verification_error: nil,
      layout_settings: Certificates.effective_layout_settings(certificate),
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate)
    )
  end

  defp render_verification_result({:invalid, reason}, conn, lookup_value) do
    conn
    |> put_status(:not_found)
    |> render(:show,
      page_title: "Certificate Not Valid",
      certificate: nil,
      certificate_number: lookup_value,
      verification_error: reason
    )
  end

  defp normalize_certificate_number(certificate_number) when is_binary(certificate_number) do
    case String.trim(certificate_number) do
      "" -> nil
      normalized_number -> normalized_number
    end
  end

  defp normalize_certificate_number(_certificate_number), do: nil
end
