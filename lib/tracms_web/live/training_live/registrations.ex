defmodule TracmsWeb.TrainingLive.Registrations do
  use TracmsWeb, :live_view

  alias Tracms.Registrations
  alias Tracms.Registrations.ExternalRegistrationSubmission
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    {:ok,
     socket
     |> assign(:page_title, "Training Registrations")
     |> assign(:training_activity, training_activity)
     |> assign(:bulk_import_result, nil)
     |> assign_form(
       Registrations.change_external_registration_submission(%ExternalRegistrationSubmission{})
     )
     |> assign_bulk_import_form(default_bulk_import_params())
     |> load_registrations()}
  end

  @impl true
  def handle_event("validate_external_submission", %{"external_submission" => params}, socket) do
    changeset =
      %ExternalRegistrationSubmission{}
      |> Registrations.change_external_registration_submission(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("validate_bulk_import", %{"bulk_import" => params}, socket) do
    {:noreply, assign_bulk_import_form(socket, params)}
  end

  def handle_event("create_external_submission", %{"external_submission" => params}, socket) do
    case Registrations.create_external_registration_submission(
           socket.assigns.current_scope,
           socket.assigns.training_activity.id,
           params
         ) do
      {:ok, _submission} ->
        {:noreply,
         socket
         |> put_flash(:info, "External registration submission added to the intake queue.")
         |> assign_form(
           Registrations.change_external_registration_submission(
             %ExternalRegistrationSubmission{}
           )
         )
         |> load_registrations()}

      {:error, :external_collection_not_enabled} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This training is not configured for an external registration workflow."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to add this external submission.")}
    end
  end

  def handle_event("bulk_import_external_submissions", %{"bulk_import" => params}, socket) do
    case Registrations.bulk_import_external_registration_submissions(
           socket.assigns.current_scope,
           socket.assigns.training_activity.id,
           params
         ) do
      {:ok, result} ->
        message =
          bulk_import_summary_message(result)

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> assign(:bulk_import_result, result)
         |> assign_bulk_import_form(default_bulk_import_params())
         |> load_registrations()}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:bulk_import_result, nil)
         |> put_flash(:error, bulk_import_error_message(reason))
         |> assign_bulk_import_form(params)}
    end
  end

  def handle_event("sync_google_sheet", _params, socket) do
    case Registrations.sync_external_registration_submissions_from_google_sheet(
           socket.assigns.current_scope,
           socket.assigns.training_activity.id
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, google_sheet_sync_summary_message(result))
         |> assign(:bulk_import_result, result)
         |> load_registrations()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, google_sheet_sync_error_message(reason))}
    end
  end

  def handle_event("review", %{"id" => id, "status" => status}, socket) do
    registration =
      Enum.find(socket.assigns.registrations, fn registration -> registration.id == id end)

    status = String.to_existing_atom(status)

    case registration &&
           Registrations.review_registration(socket.assigns.current_scope, registration, status) do
      {:ok, _registration} ->
        {:noreply,
         socket
         |> put_flash(:info, "Registration updated successfully.")
         |> load_registrations()}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update this registration.")}
    end
  end

  def handle_event("import_external_submission", %{"id" => id}, socket) do
    submission =
      Enum.find(socket.assigns.external_submissions, fn submission -> submission.id == id end)

    case submission &&
           Registrations.import_external_registration_submission(
             socket.assigns.current_scope,
             submission
           ) do
      {:ok, registration} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "External submission imported into the TRACMS registration queue for #{participant_name(registration)}."
         )
         |> load_registrations()}

      {:error, :account_not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No matching TRACMS account was found for this external submission yet."
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to import this external submission.")}
    end
  end

  def handle_event("reject_external_submission", %{"id" => id}, socket) do
    submission =
      Enum.find(socket.assigns.external_submissions, fn submission -> submission.id == id end)

    case submission &&
           Registrations.reject_external_registration_submission(
             socket.assigns.current_scope,
             submission
           ) do
      {:ok, _submission} ->
        {:noreply,
         socket
         |> put_flash(:info, "External submission marked as rejected.")
         |> load_registrations()}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update this external submission.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="trainings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Registration management"
          title={@training_activity.title}
          copy="Review submitted participants and update registration decisions. External workflow trainings can also stage official form responses here before converting them into TRACMS registrations."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}/integrations"} variant="ghost">
              Google Workspace
            </.button>
            <.button
              :if={external_workflow?(@training_activity)}
              href={@training_activity.registration_form_url}
              target="_blank"
              rel="noreferrer"
              variant="secondary"
            >
              Open registration form
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section :if={external_workflow?(@training_activity)} class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="External intake"
            title="External registration queue"
            meta="Encode official form responses here before converting them into real TRACMS registrations."
          />

          <.form
            for={@external_submission_form}
            id="external-submission-form"
            phx-change="validate_external_submission"
            phx-submit="create_external_submission"
          >
            <div class="grid gap-5 md:grid-cols-2">
              <.input field={@external_submission_form[:full_name]} type="text" label="Full name" />
              <.input field={@external_submission_form[:email]} type="email" label="Email address" />
              <.input
                field={@external_submission_form[:employee_number]}
                type="text"
                label="Employee number"
              />
              <.input
                field={@external_submission_form[:office_name]}
                type="text"
                label="Office or school"
              />
              <.input
                field={@external_submission_form[:source_reference]}
                type="text"
                label="Form reference"
                placeholder="Google Sheet row, response ID, or batch note"
              />
              <div class="md:col-span-2">
                <.input
                  field={@external_submission_form[:special_requirements]}
                  type="textarea"
                  label="Special requirements or coordinator notes"
                  rows="4"
                />
              </div>
            </div>

            <div class="mt-6 flex justify-end">
              <.button phx-disable-with="Adding to queue...">Add to intake queue</.button>
            </div>
          </.form>
        </section>

        <section :if={external_workflow?(@training_activity)} class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Bulk intake"
            title="Paste spreadsheet rows"
            meta="Paste copied rows from Google Sheets or a simple CSV export with a header row."
          >
            <:actions>
              <.button
                :if={google_sheet_sync_ready?(@training_activity)}
                type="button"
                phx-click="sync_google_sheet"
                variant="secondary"
              >
                Sync Google Sheet now
              </.button>
            </:actions>
          </.portal_panel_header>

          <div class="space-y-5">
            <div class="portal-workflow-list">
              <div class={[
                "portal-workflow-item",
                if(google_sheet_sync_ready?(@training_activity),
                  do: "portal-workflow-item-green",
                  else: "portal-workflow-item-amber"
                )
              ]}>
                <div>
                  <p class="portal-workflow-label">Google Sheets sync status</p>
                  <p class="portal-workflow-copy">
                    {google_sheet_sync_copy(@training_activity)}
                  </p>
                </div>
                <span class="portal-workflow-value">
                  {google_sheet_sync_label(@training_activity)}
                </span>
              </div>
            </div>
            <p class="section-copy">
              Supported headers: `full_name` or `name`, `email`, `employee_number`, `office_name` or `school`, `source_reference`, and `special_requirements` or `notes`.
            </p>

            <.form
              for={@bulk_import_form}
              id="bulk-import-form"
              phx-change="validate_bulk_import"
              phx-submit="bulk_import_external_submissions"
            >
              <div class="grid gap-5">
                <.input
                  field={@bulk_import_form[:batch_reference]}
                  type="text"
                  label="Batch reference"
                  placeholder="Google Sheet batch A"
                />
                <.input
                  field={@bulk_import_form[:tabular_data]}
                  type="textarea"
                  label="Spreadsheet data"
                  rows="10"
                  placeholder="full_name\temail\temployee_number\toffice_name\nJuan Dela Cruz\tjuan@example.com\tEMP-1001\tRegional Office IX"
                />
              </div>

              <div class="mt-6 flex justify-end">
                <.button phx-disable-with="Importing rows...">Stage rows in bulk</.button>
              </div>
            </.form>

            <%= if @bulk_import_result do %>
              <div class="portal-workflow-list">
                <div class="portal-workflow-item portal-workflow-item-green">
                  <div>
                    <p class="portal-workflow-label">Rows staged successfully</p>
                    <p class="portal-workflow-copy">
                      Valid rows were added to the external intake queue and matched against existing TRACMS accounts when possible.
                    </p>
                  </div>
                  <span class="portal-workflow-value">{@bulk_import_result.created_count}</span>
                </div>
                <div class={[
                  "portal-workflow-item",
                  if(@bulk_import_result.error_count > 0,
                    do: "portal-workflow-item-amber",
                    else: "portal-workflow-item-slate"
                  )
                ]}>
                  <div>
                    <p class="portal-workflow-label">Rows needing correction</p>
                    <p class="portal-workflow-copy">
                      These rows were skipped so you can correct the source data and paste them again.
                    </p>
                  </div>
                  <span class="portal-workflow-value">{@bulk_import_result.error_count}</span>
                </div>
                <div class={[
                  "portal-workflow-item",
                  if(@bulk_import_result.skipped_count > 0,
                    do: "portal-workflow-item-blue",
                    else: "portal-workflow-item-slate"
                  )
                ]}>
                  <div>
                    <p class="portal-workflow-label">Rows skipped as duplicates</p>
                    <p class="portal-workflow-copy">
                      These rows already exist in the intake queue and were not staged again.
                    </p>
                  </div>
                  <span class="portal-workflow-value">{@bulk_import_result.skipped_count}</span>
                </div>
              </div>

              <div :if={@bulk_import_result.errors != []} class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Row</th>
                      <th>Issue</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={error <- @bulk_import_result.errors}>
                      <td>{error.row}</td>
                      <td>{error.message}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </section>

        <section :if={external_workflow?(@training_activity)} class="panel portal-list-panel">
          <%= if @external_submissions == [] do %>
            <.portal_empty_state
              icon="hero-document-text"
              title="No external submissions yet"
              copy="Manager-encoded Google Form or external registration responses will appear here before import."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Staging records"
              title="External submission review"
              meta={external_submission_caption(@external_submissions)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Source</th>
                    <th>Matched account</th>
                    <th>Status</th>
                    <th>Imported registration</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={submission <- @external_submissions}>
                    <td>
                      <div class="portal-cell-title">{submission.full_name}</div>
                      <div class="portal-cell-meta">{submission.email}</div>
                    </td>
                    <td>
                      <div>{submission.source_reference || "Manual intake"}</div>
                      <div class="portal-cell-meta">
                        {submission.office_name || "No office provided"}
                      </div>
                    </td>
                    <td>
                      <%= if submission.matched_user do %>
                        <div class="portal-cell-title">
                          {submission.matched_user.full_name || submission.matched_user.email}
                        </div>
                        <div class="portal-cell-meta">{submission.matched_user.email}</div>
                      <% else %>
                        <span class="text-sm text-amber-600">No TRACMS account matched yet</span>
                      <% end %>
                    </td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{external_submission_tone(submission.status)}"
                      ]}>
                        {external_submission_status_label(submission.status)}
                      </span>
                    </td>
                    <td>
                      <%= if submission.imported_registration do %>
                        <div class="portal-cell-title">
                          {Registrations.format_status(submission.imported_registration.status)}
                        </div>
                        <div class="portal-cell-meta">
                          {participant_name(submission.imported_registration)}
                        </div>
                      <% else %>
                        Not yet imported
                      <% end %>
                    </td>
                    <td>
                      <div class="portal-action-stack">
                        <.button
                          :if={submission.status in [:pending_review, :needs_account]}
                          phx-click="import_external_submission"
                          phx-value-id={submission.id}
                          variant="secondary"
                        >
                          Import to TRACMS
                        </.button>
                        <.button
                          :if={submission.status in [:pending_review, :needs_account]}
                          phx-click="reject_external_submission"
                          phx-value-id={submission.id}
                          variant="ghost"
                        >
                          Reject intake
                        </.button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          <% end %>
        </section>

        <%= if @registrations == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-user-group"
              title="No TRACMS registrations yet"
              copy="Submitted participant registrations for this training will appear here after direct portal registration or external intake import."
            />
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Participant queue"
              title="Registration decisions"
              meta={registration_caption(@registrations)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Submitted</th>
                    <th>Requirements</th>
                    <th>Status</th>
                    <th>Review notes</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={registration <- @registrations}>
                    <td>
                      <div class="portal-cell-title">{participant_name(registration)}</div>
                      <div class="portal-cell-meta">{registration.registrant_user.email}</div>
                    </td>
                    <td>{format_datetime(registration.submitted_at)}</td>
                    <td>{registration.special_requirements || "None"}</td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{registration_status_tone(registration.status)}"
                      ]}>
                        {Registrations.format_status(registration.status)}
                      </span>
                    </td>
                    <td>{registration.review_notes || "No review notes yet"}</td>
                    <td>
                      <div class="portal-action-stack">
                        <.button
                          :if={registration.status in [:submitted, :waitlisted]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="approved"
                          variant="secondary"
                        >
                          Approve
                        </.button>
                        <.button
                          :if={registration.status in [:submitted, :approved]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="waitlisted"
                          variant="ghost"
                        >
                          Waitlist
                        </.button>
                        <.button
                          :if={registration.status in [:submitted, :approved, :waitlisted]}
                          phx-click="review"
                          phx-value-id={registration.id}
                          phx-value-status="rejected"
                          variant="danger"
                        >
                          Reject
                        </.button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_registrations(socket) do
    training_activity =
      Trainings.get_training_activity!(
        socket.assigns.current_scope,
        socket.assigns.training_activity.id
      )

    registrations =
      Registrations.list_training_registrations(
        socket.assigns.current_scope,
        training_activity.id
      )

    external_submissions =
      if external_workflow?(training_activity) do
        Registrations.list_external_registration_submissions(
          socket.assigns.current_scope,
          training_activity.id
        )
      else
        []
      end

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:registrations, registrations)
    |> assign(:external_submissions, external_submissions)
    |> assign(:summary_cards, registration_summary_cards(registrations, external_submissions))
  end

  defp registration_summary_cards(registrations, external_submissions) do
    [
      summary_card("Total registrations", length(registrations), "Submitted participant records"),
      summary_card(
        "Pending review",
        Enum.count(registrations, &(&1.status == :submitted)),
        "Awaiting a registration decision"
      ),
      summary_card(
        "Approved",
        Enum.count(registrations, &(&1.status == :approved)),
        "Confirmed for participation"
      ),
      summary_card(
        "Waitlisted or rejected",
        Enum.count(registrations, &(&1.status in [:waitlisted, :rejected])),
        "Not yet confirmed for the training"
      )
    ] ++
      if external_submissions == [] do
        []
      else
        [
          summary_card(
            "External intake queue",
            Enum.count(external_submissions, &(&1.status in [:pending_review, :needs_account])),
            "Staged external responses awaiting import or rejection"
          )
        ]
      end
  end

  defp registration_caption(registrations) do
    count = length(registrations)
    "Showing #{count} participant #{if(count == 1, do: "registration", else: "registrations")}."
  end

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp external_submission_caption(submissions) do
    count = length(submissions)
    "Showing #{count} external #{if(count == 1, do: "submission", else: "submissions")}."
  end

  defp external_submission_status_label(status) do
    status
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp external_workflow?(training_activity) do
    is_binary(training_activity.registration_form_url) and
      training_activity.registration_form_url != ""
  end

  defp registration_status_tone(:approved), do: "green"
  defp registration_status_tone(:submitted), do: "blue"
  defp registration_status_tone(:waitlisted), do: "amber"
  defp registration_status_tone(:rejected), do: "rose"
  defp registration_status_tone(_status), do: "slate"

  defp external_submission_tone(:pending_review), do: "blue"
  defp external_submission_tone(:needs_account), do: "amber"
  defp external_submission_tone(:imported), do: "green"
  defp external_submission_tone(:rejected), do: "rose"
  defp external_submission_tone(_status), do: "slate"

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :external_submission_form, to_form(changeset, as: :external_submission))
  end

  defp assign_bulk_import_form(socket, params) do
    assign(socket, :bulk_import_form, to_form(params, as: :bulk_import))
  end

  defp default_bulk_import_params do
    %{"batch_reference" => "", "tabular_data" => ""}
  end

  defp bulk_import_summary_message(result) do
    "Bulk intake completed. #{result.created_count} row(s) staged, #{result.skipped_count} duplicate row(s) skipped, and #{result.error_count} row(s) need correction."
  end

  defp bulk_import_error_message(:empty_import_data),
    do: "Paste spreadsheet data before starting the bulk intake."

  defp bulk_import_error_message(:no_import_rows),
    do: "The pasted data must include at least one row after the header."

  defp bulk_import_error_message({:missing_import_headers, headers}) do
    "Missing required headers: #{Enum.join(headers, ", ")}."
  end

  defp bulk_import_error_message(:external_collection_not_enabled) do
    "This training is not configured for an external registration workflow."
  end

  defp bulk_import_error_message(_reason) do
    "Unable to process the bulk import right now."
  end

  defp google_sheet_sync_ready?(training_activity) do
    is_binary(training_activity.registration_sheet_id) and
      training_activity.registration_sheet_id != "" and
      is_binary(training_activity.registration_sheet_range) and
      training_activity.registration_sheet_range != ""
  end

  defp google_sheet_sync_label(training_activity) do
    if google_sheet_sync_ready?(training_activity), do: "Ready", else: "Not configured"
  end

  defp google_sheet_sync_copy(training_activity) do
    cond do
      google_sheet_sync_ready?(training_activity) and
          training_activity.registration_sheet_last_synced_at ->
        "Sheet #{training_activity.registration_sheet_id} • range #{training_activity.registration_sheet_range} • last synced #{format_datetime(training_activity.registration_sheet_last_synced_at)}"

      google_sheet_sync_ready?(training_activity) ->
        "Sheet #{training_activity.registration_sheet_id} • range #{training_activity.registration_sheet_range} • no successful sync yet"

      true ->
        "Add a Google Sheet ID and range on the training record before using automatic synchronization."
    end
  end

  defp google_sheet_sync_summary_message(result) do
    "Google Sheets sync completed. #{result.created_count} row(s) staged, #{result.skipped_count} duplicate row(s) skipped, and #{result.error_count} row(s) need correction."
  end

  defp google_sheet_sync_error_message(:google_sheet_sync_not_configured) do
    "Configure the Google Sheet ID and range on this training before running synchronization."
  end

  defp google_sheet_sync_error_message(:missing_google_service_account_json) do
    "The GOOGLE_SERVICE_ACCOUNT_JSON environment variable is not configured for Sheets access."
  end

  defp google_sheet_sync_error_message(:invalid_google_service_account_json) do
    "The GOOGLE_SERVICE_ACCOUNT_JSON value is not a valid service account JSON document."
  end

  defp google_sheet_sync_error_message(:google_sheet_has_no_values) do
    "The configured Google Sheet range did not return any values."
  end

  defp google_sheet_sync_error_message({:google_sheet_request_failed, _body}) do
    "Google Sheets returned an error while reading the configured range."
  end

  defp google_sheet_sync_error_message({:google_token_request_failed, _body}) do
    "TRACMS could not obtain a Google access token for the configured service account."
  end

  defp google_sheet_sync_error_message(:google_sheet_not_found) do
    "The configured Google Sheet could not be reached with the current settings."
  end

  defp google_sheet_sync_error_message(_reason) do
    "Unable to synchronize Google Sheets right now."
  end
end
