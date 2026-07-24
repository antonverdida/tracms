defmodule Tracms.GoogleForms.TestClient do
  @behaviour Tracms.GoogleForms

  @impl true
  def create_form(%{title: title} = attrs) do
    kind =
      cond do
        String.contains?(title, "Registration Form") -> "registration"
        String.contains?(title, "Attendance") -> "attendance"
        true -> "generic"
      end

    form_id = "generated-#{kind}-form"

    {:ok,
     %{
       form_id: form_id,
       responder_uri: "https://docs.google.com/forms/d/#{form_id}/viewform",
       edit_uri: "https://docs.google.com/forms/d/#{form_id}/edit",
       linked_sheet_id: Map.get(attrs, :linked_sheet_id)
     }}
  end
end
