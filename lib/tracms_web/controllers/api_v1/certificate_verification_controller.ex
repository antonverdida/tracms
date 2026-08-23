defmodule TracmsWeb.ApiV1.CertificateVerificationController do
  use TracmsWeb, :controller

  alias Tracms.Certificates

  def show_by_verification_code(conn, %{"verification_code" => verification_code}) do
    verification_code
    |> Certificates.verify_certificate_by_code()
    |> render_result(conn)
  end

  def show_by_certificate_number(conn, %{"certificate_number" => certificate_number}) do
    certificate_number
    |> Certificates.verify_certificate_by_number()
    |> render_result(conn)
  end

  def show_by_certificate_number(conn, _params) do
    invalid_request(conn, "certificate_number is required.")
  end

  defp render_result({:valid, certificate}, conn) do
    registration = certificate.registration
    training = registration.training_activity

    json(conn, %{
      data: %{
        verification: %{
          status: "valid",
          checked_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
          certificate: %{
            certificate_number: certificate.certificate_number,
            certificate_type: certificate.certificate_type,
            issued_on: Date.to_iso8601(certificate.issued_on),
            holder_name: holder_name(registration),
            training_title: training.title,
            training_dates: training_dates(training.starts_on, training.ends_on),
            organizer: training.organizer
          }
        }
      }
    })
  end

  defp render_result({:invalid, :revoked}, conn) do
    conn
    |> put_status(:gone)
    |> json(%{
      error: %{code: "certificate_revoked", message: "This certificate has been revoked."}
    })
  end

  defp render_result({:invalid, _reason}, conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "certificate_not_found", message: "No valid certificate was found."}})
  end

  defp invalid_request(conn, message) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "invalid_request", message: message}})
  end

  defp holder_name(%{manual_participant_name: name}) when is_binary(name) and name != "", do: name
  defp holder_name(%{registrant_user: %{full_name: name}}), do: name
  defp holder_name(_registration), do: "Certificate holder"

  defp training_dates(starts_on, ends_on) do
    %{
      starts_on: starts_on && Date.to_iso8601(starts_on),
      ends_on: ends_on && Date.to_iso8601(ends_on)
    }
  end
end
