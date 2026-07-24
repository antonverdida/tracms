defmodule Tracms.GoogleSheets.Client do
  @moduledoc false

  @behaviour Tracms.GoogleSheets

  alias Tracms.GoogleWorkspace.Auth

  @token_scope "https://www.googleapis.com/auth/spreadsheets.readonly"

  @impl true
  def fetch_values(spreadsheet_id, range) do
    with {:ok, config} <- Auth.service_account_config(),
         {:ok, access_token} <- Auth.fetch_access_token(config, [@token_scope]),
         {:ok, response} <- fetch_sheet_values(config, spreadsheet_id, range, access_token),
         {:ok, values} <- extract_values(response) do
      normalize_values(values)
    end
  end

  defp fetch_sheet_values(_config, spreadsheet_id, range, access_token) do
    encoded_range = URI.encode(range)

    Req.get(
      "https://sheets.googleapis.com/v4/spreadsheets/#{spreadsheet_id}/values/#{encoded_range}",
      auth: {:bearer, access_token},
      params: [majorDimension: "ROWS"]
    )
  end

  defp extract_values(%{status: 200, body: %{"values" => values}}) when is_list(values),
    do: {:ok, values}

  defp extract_values(%{status: 200}), do: {:error, :google_sheet_has_no_values}
  defp extract_values(%{body: body}), do: {:error, {:google_sheet_request_failed, body}}

  defp normalize_values([headers | rows]) when is_list(headers) do
    {:ok,
     %{
       headers: Enum.map(headers, &to_string/1),
       rows: Enum.map(rows, fn row -> Enum.map(row, &to_string/1) end)
     }}
  end

  defp normalize_values(_values), do: {:error, :google_sheet_has_no_values}
end
