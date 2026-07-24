defmodule TracmsWeb.CertificateDocumentController do
  use TracmsWeb, :controller

  alias Tracms.Certificates
  alias TracmsWeb.CertificateComponents

  def participant_print(conn, %{"id" => certificate_id}) do
    certificate =
      case Certificates.acknowledge_certificate_access(conn.assigns.current_scope, certificate_id) do
        {:ok, certificate} ->
          certificate

        {:error, :not_found} ->
          raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord
      end

    conn
    |> put_root_layout(false)
    |> render(:document,
      page_title: "#{certificate.certificate_type} Print View",
      certificate: certificate,
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: true,
      export_path: ~p"/my/certificates/#{certificate.id}/export",
      back_path: ~p"/my/certificates/#{certificate.id}",
      back_label: "Back to certificate"
    )
  end

  def participant_export(conn, %{"id" => certificate_id}) do
    certificate =
      case Certificates.acknowledge_certificate_access(conn.assigns.current_scope, certificate_id) do
        {:ok, certificate} ->
          certificate

        {:error, :not_found} ->
          raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord
      end

    conn
    |> put_root_layout(false)
    |> put_resp_header("content-disposition", content_disposition(certificate))
    |> render(:document,
      page_title: "#{certificate.certificate_type} Export",
      certificate: certificate,
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: false,
      export_path: nil,
      back_path: ~p"/my/certificates/#{certificate.id}",
      back_label: "Back to certificate"
    )
  end

  def manager_print(conn, %{"training_id" => training_id, "certificate_id" => certificate_id}) do
    certificate =
      get_manager_certificate!(conn.assigns.current_scope, training_id, certificate_id)

    conn
    |> put_root_layout(false)
    |> render(:document,
      page_title: "#{certificate.certificate_type} Print View",
      certificate: certificate,
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: true,
      export_path: ~p"/trainings/#{training_id}/certificates/#{certificate.id}/export",
      back_path: ~p"/trainings/#{training_id}/certificates/#{certificate.id}",
      back_label: "Back to preview"
    )
  end

  def manager_export(conn, %{"training_id" => training_id, "certificate_id" => certificate_id}) do
    certificate =
      get_manager_certificate!(conn.assigns.current_scope, training_id, certificate_id)

    conn
    |> put_root_layout(false)
    |> put_resp_header("content-disposition", content_disposition(certificate))
    |> render(:document,
      page_title: "#{certificate.certificate_type} Export",
      certificate: certificate,
      participant_name: CertificateComponents.certificate_participant_name(certificate),
      issued_by_name: CertificateComponents.certificate_issued_by_name(certificate),
      scope_label: CertificateComponents.certificate_scope_label(certificate),
      autoprint: false,
      export_path: nil,
      back_path: ~p"/trainings/#{training_id}/certificates/#{certificate.id}",
      back_label: "Back to preview"
    )
  end

  defp get_manager_certificate!(scope, training_id, certificate_id) do
    case Certificates.get_training_certificate(scope, training_id, certificate_id) do
      nil ->
        raise Ecto.NoResultsError, queryable: Tracms.Certificates.CertificateRecord

      certificate ->
        certificate
    end
  end

  defp content_disposition(certificate) do
    ~s(attachment; filename="#{document_filename(certificate)}")
  end

  defp document_filename(certificate) do
    number_slug =
      certificate.certificate_number
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/u, "-")
      |> String.trim("-")

    "tracms-certificate-#{number_slug}.html"
  end
end
