defmodule Tracms.GoogleWorkspace.Auth do
  @moduledoc false

  @token_grant_type "urn:ietf:params:oauth:grant-type:jwt-bearer"
  @default_token_uri "https://oauth2.googleapis.com/token"

  def service_account_config do
    case System.get_env("GOOGLE_SERVICE_ACCOUNT_JSON") do
      json when is_binary(json) and json != "" ->
        json
        |> Jason.decode()
        |> case do
          {:ok, %{"client_email" => client_email, "private_key" => private_key} = config} ->
            {:ok,
             %{
               client_email: client_email,
               private_key: private_key,
               token_uri: Map.get(config, "token_uri", @default_token_uri)
             }}

          _ ->
            {:error, :invalid_google_service_account_json}
        end

      _ ->
        {:error, :missing_google_service_account_json}
    end
  end

  def fetch_access_token(config, scopes) when is_list(scopes) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = %{
      "iss" => config.client_email,
      "scope" => Enum.join(scopes, " "),
      "aud" => config.token_uri,
      "exp" => now + 3600,
      "iat" => now
    }

    assertion =
      sign_jwt(
        %{"alg" => "RS256", "typ" => "JWT"},
        claims,
        config.private_key
      )

    case Req.post(config.token_uri,
           form: [grant_type: @token_grant_type, assertion: assertion]
         ) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        {:ok, access_token}

      {:ok, %{body: body}} ->
        {:error, {:google_token_request_failed, body}}

      {:error, reason} ->
        {:error, {:google_token_request_failed, reason}}
    end
  end

  defp sign_jwt(header, claims, private_key_pem) do
    signing_input =
      [header, claims]
      |> Enum.map_join(".", fn part ->
        part
        |> Jason.encode!()
        |> Base.url_encode64(padding: false)
      end)

    [pem_entry] = :public_key.pem_decode(String.to_charlist(private_key_pem))
    private_key = :public_key.pem_entry_decode(pem_entry)
    signature = :public_key.sign(signing_input, :sha256, private_key)

    signing_input <> "." <> Base.url_encode64(signature, padding: false)
  end
end
