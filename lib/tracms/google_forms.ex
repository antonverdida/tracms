defmodule Tracms.GoogleForms do
  @moduledoc """
  Google Forms generation support for TRACMS using a service account.
  """

  @callback create_form(map()) ::
              {:ok,
               %{
                 form_id: String.t(),
                 responder_uri: String.t(),
                 edit_uri: String.t(),
                 linked_sheet_id: String.t() | nil
               }}
              | {:error, term()}

  def create_form(attrs) when is_map(attrs) do
    client().create_form(attrs)
  end

  defp client do
    Application.get_env(:tracms, :google_forms_client, Tracms.GoogleForms.Client)
  end
end
