defmodule Tracms.GoogleSheets do
  @moduledoc """
  Google Sheets intake support for TRACMS using a service account.
  """

  @callback fetch_values(String.t(), String.t()) ::
              {:ok, %{headers: [String.t()], rows: [[String.t()]]}} | {:error, term()}

  def fetch_values(spreadsheet_id, range) when is_binary(spreadsheet_id) and is_binary(range) do
    client().fetch_values(spreadsheet_id, range)
  end

  defp client do
    Application.get_env(:tracms, :google_sheets_client, Tracms.GoogleSheets.Client)
  end
end
