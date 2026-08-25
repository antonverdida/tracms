defmodule Tracms.Certificates.Notifier do
  @moduledoc false

  import Swoosh.Email

  alias Swoosh.Attachment
  alias Tracms.Mailer
  alias Tracms.Registrations
  alias TracmsWeb.CertificateDocumentController

  def deliver(certificate) do
    with email when is_binary(email) and email != "" <-
           Registrations.participant_email(certificate.registration),
         pdf_binary <- CertificateDocumentController.pdf_binary(certificate),
         {:ok, _metadata} <-
           new()
           |> to(email)
           |> from({"DepEd Region IX TRACMS", "noreply@tracms.local"})
           |> subject("Your #{certificate.certificate_type}")
           |> text_body(
             "Your certificate is attached. Certificate No.: #{certificate.certificate_number}"
           )
           |> attachment(
             Attachment.new({:data, pdf_binary},
               filename: CertificateDocumentController.pdf_filename(certificate),
               content_type: "application/pdf"
             )
           )
           |> Mailer.deliver() do
      :ok
    else
      nil -> {:error, :missing_email}
      "" -> {:error, :missing_email}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end
