defmodule Tracms.GoogleForms.Client do
  @moduledoc false

  @behaviour Tracms.GoogleForms

  alias Tracms.GoogleWorkspace.Auth

  @token_scopes [
    "https://www.googleapis.com/auth/forms.body",
    "https://www.googleapis.com/auth/drive.file"
  ]

  @impl true
  def create_form(attrs) do
    with {:ok, config} <- Auth.service_account_config(),
         {:ok, access_token} <- Auth.fetch_access_token(config, @token_scopes),
         {:ok, created_form} <- create_unpublished_form(attrs, access_token),
         {:ok, _updated_form} <-
           update_form_contents(created_form["formId"], attrs, access_token),
         :ok <- publish_form(created_form["formId"], access_token),
         :ok <-
           maybe_share_form(
             created_form["formId"],
             attrs[:share_with] || attrs["share_with"],
             access_token
           ),
         {:ok, form} <- get_form(created_form["formId"], access_token) do
      {:ok,
       %{
         form_id: form["formId"],
         responder_uri: form["responderUri"],
         edit_uri: "https://docs.google.com/forms/d/#{form["formId"]}/edit",
         linked_sheet_id: form["linkedSheetId"]
       }}
    end
  end

  defp create_unpublished_form(attrs, access_token) do
    body = %{
      info: %{
        title: attrs[:title] || attrs["title"],
        documentTitle:
          attrs[:document_title] || attrs["document_title"] || attrs[:title] || attrs["title"]
      }
    }

    case Req.post("https://forms.googleapis.com/v1/forms",
           auth: {:bearer, access_token},
           json: body,
           params: [unpublished: true]
         ) do
      {:ok, %{status: 200, body: form}} -> {:ok, form}
      {:ok, %{body: body}} -> {:error, {:google_form_create_failed, body}}
      {:error, reason} -> {:error, {:google_form_create_failed, reason}}
    end
  end

  defp update_form_contents(form_id, attrs, access_token) do
    requests =
      []
      |> maybe_add_description(attrs[:description] || attrs["description"])
      |> maybe_add_settings(attrs[:email_collection_type] || attrs["email_collection_type"])
      |> add_item_requests(attrs[:items] || attrs["items"] || [])

    case Req.post("https://forms.googleapis.com/v1/forms/#{form_id}:batchUpdate",
           auth: {:bearer, access_token},
           json: %{requests: requests, includeFormInResponse: false}
         ) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{body: body}} -> {:error, {:google_form_update_failed, body}}
      {:error, reason} -> {:error, {:google_form_update_failed, reason}}
    end
  end

  defp publish_form(form_id, access_token) do
    case Req.post("https://forms.googleapis.com/v1/forms/#{form_id}:setPublishSettings",
           auth: {:bearer, access_token},
           json: %{
             publishSettings: %{
               publishState: %{
                 isPublished: true,
                 isAcceptingResponses: true
               }
             },
             updateMask: "publishState.isPublished,publishState.isAcceptingResponses"
           }
         ) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{body: body}} -> {:error, {:google_form_publish_failed, body}}
      {:error, reason} -> {:error, {:google_form_publish_failed, reason}}
    end
  end

  defp maybe_share_form(_form_id, nil, _access_token), do: :ok
  defp maybe_share_form(_form_id, "", _access_token), do: :ok

  defp maybe_share_form(form_id, email, access_token) do
    case Req.post("https://www.googleapis.com/drive/v3/files/#{form_id}/permissions",
           auth: {:bearer, access_token},
           json: %{
             role: "writer",
             type: "user",
             emailAddress: email
           },
           params: [sendNotificationEmail: false]
         ) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{body: body}} -> {:error, {:google_drive_permission_failed, body}}
      {:error, reason} -> {:error, {:google_drive_permission_failed, reason}}
    end
  end

  defp get_form(form_id, access_token) do
    case Req.get("https://forms.googleapis.com/v1/forms/#{form_id}",
           auth: {:bearer, access_token}
         ) do
      {:ok, %{status: 200, body: form}} -> {:ok, form}
      {:ok, %{body: body}} -> {:error, {:google_form_fetch_failed, body}}
      {:error, reason} -> {:error, {:google_form_fetch_failed, reason}}
    end
  end

  defp maybe_add_description(requests, nil), do: requests
  defp maybe_add_description(requests, ""), do: requests

  defp maybe_add_description(requests, description) do
    requests ++
      [
        %{
          updateFormInfo: %{
            info: %{description: description},
            updateMask: "description"
          }
        }
      ]
  end

  defp maybe_add_settings(requests, nil), do: requests
  defp maybe_add_settings(requests, ""), do: requests

  defp maybe_add_settings(requests, email_collection_type) do
    requests ++
      [
        %{
          updateSettings: %{
            settings: %{emailCollectionType: email_collection_type},
            updateMask: "emailCollectionType"
          }
        }
      ]
  end

  defp add_item_requests(requests, items) do
    items
    |> Enum.with_index()
    |> Enum.reduce(requests, fn {item, index}, acc ->
      acc ++
        [
          %{
            createItem: %{
              item: item,
              location: %{index: index}
            }
          }
        ]
    end)
  end
end
