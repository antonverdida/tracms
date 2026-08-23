defmodule TracmsWeb.RegistrationExportHTML do
  use TracmsWeb, :html

  alias Tracms.Registrations

  embed_templates "registration_export_html/*"

  def registration_number(id) do
    suffix =
      id
      |> String.replace("-", "")
      |> String.slice(-6, 6)
      |> String.upcase()

    "REG-#{suffix}"
  end

  def participant_name(registration) do
    Registrations.participant_name(registration)
  end

  def organization_name(registration) do
    Registrations.participant_organization(registration)
  end

  def participant_email(registration),
    do: Registrations.participant_email(registration) || "Not provided"

  def registration_status_label(status) when status in [:submitted, :approved, :waitlisted],
    do: "Registered"

  def registration_status_label(_status), do: "Cancelled"
end
