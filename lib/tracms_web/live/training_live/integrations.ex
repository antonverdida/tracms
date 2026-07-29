defmodule TracmsWeb.TrainingLive.Integrations do
  use TracmsWeb, :live_view

  alias Tracms.Attendance
  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Google Workspace Integration")
     |> assign(:training_id, training_id)
     |> assign(:registration_sync_result, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load_page(socket)}
  end

  @impl true
  def handle_event("sync_registration_sheet", _params, socket) do
    case Registrations.sync_external_registration_submissions_from_google_sheet(
           socket.assigns.current_scope,
           socket.assigns.training_activity.id
         ) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, registration_sync_summary(result))
         |> load_page()
         |> assign(:registration_sync_result, result)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, registration_sync_error_message(reason))}
    end
  end

  def handle_event("generate_registration_form", _params, socket) do
    case Trainings.generate_google_form(
           socket.assigns.current_scope,
           socket.assigns.training_activity,
           :registration
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google registration form generated successfully.")
         |> load_page(training_activity.id)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, google_form_error_message(reason))}
    end
  end

  def handle_event("generate_attendance_form", _params, socket) do
    case Trainings.generate_google_form(
           socket.assigns.current_scope,
           socket.assigns.training_activity,
           :attendance
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google attendance form generated successfully.")
         |> load_page(training_activity.id)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, google_form_error_message(reason))}
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
          eyebrow="Google Workspace integration"
          title={@training_activity.title}
          copy="Centralize external registration and attendance collection while keeping TRACMS as the official monitoring, validation, and certification record."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/registrations"}
              variant="ghost"
            >
              Registration management
            </.button>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/completion"}
              variant="ghost"
            >
              Completion tracking
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Integration control center"
            title="Google services"
            meta="Review connected forms, response sheets, and operational readiness for this training."
          />

          <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Registration Form</div>
                  <div class="feature-copy">
                    Participant-facing Google Form used for external registration.
                  </div>
                </div>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{connection_tone(@registration_form_connected?)}"
                ]}>
                  {connection_label(@registration_form_connected?)}
                </span>
              </div>

              <p class="mt-4 section-copy">
                {connection_detail(
                  @registration_form_connected?,
                  "Use the training form to add the official registration form URL."
                )}
              </p>

              <div :if={@registration_form_connected?} class="mt-4">
                <.button
                  href={@training_activity.registration_form_url}
                  target="_blank"
                  rel="noreferrer"
                  variant="secondary"
                >
                  Open registration form
                </.button>
              </div>

              <div class="mt-4 flex flex-wrap gap-3">
                <.button phx-click="generate_registration_form">
                  {if @registration_form_connected?,
                    do: "Regenerate registration form",
                    else: "Generate registration form"}
                </.button>
                <.button
                  :if={@training_activity.registration_form_id}
                  href={google_form_edit_url(@training_activity.registration_form_id)}
                  target="_blank"
                  rel="noreferrer"
                  variant="ghost"
                >
                  Manage in Google Forms
                </.button>
              </div>
            </article>

            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Registration Response Sheet</div>
                  <div class="feature-copy">
                    Google Sheet source synchronized into the TRACMS intake queue.
                  </div>
                </div>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{connection_tone(@registration_sheet_connected?)}"
                ]}>
                  {connection_label(@registration_sheet_connected?)}
                </span>
              </div>

              <div class="mt-4 space-y-2 text-sm text-slate-600">
                <p>Sheet ID: {@training_activity.registration_sheet_id || "Not configured"}</p>
                <p>Range: {@training_activity.registration_sheet_range || "Not configured"}</p>
                <p>
                  Last sync: {format_sync_timestamp(
                    @training_activity.registration_sheet_last_synced_at
                  )}
                </p>
                <p :if={
                  @training_activity.registration_sheet_id &&
                    !configured?(@training_activity.registration_sheet_range)
                }>
                  Link a response sheet in Google Forms, then add the range here for TRACMS sync.
                </p>
              </div>

              <div class="mt-4 flex flex-wrap gap-3">
                <.button
                  :if={@registration_sheet_connected?}
                  phx-click="sync_registration_sheet"
                >
                  Sync registration intake
                </.button>
                <.button
                  navigate={~p"/trainings/#{@training_activity.id}/registrations"}
                  variant="ghost"
                >
                  Review intake queue
                </.button>
              </div>
            </article>

            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Attendance Form</div>
                  <div class="feature-copy">
                    External attendance submission point for approved participants.
                  </div>
                </div>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{connection_tone(@attendance_form_connected?)}"
                ]}>
                  {connection_label(@attendance_form_connected?)}
                </span>
              </div>

              <p class="mt-4 section-copy">
                {connection_detail(
                  @attendance_form_connected?,
                  "Use the training form to add the official attendance form URL."
                )}
              </p>

              <div :if={@attendance_form_connected?} class="mt-4">
                <.button
                  href={@training_activity.attendance_form_url}
                  target="_blank"
                  rel="noreferrer"
                  variant="secondary"
                >
                  Open attendance form
                </.button>
              </div>

              <div class="mt-4 flex flex-wrap gap-3">
                <.button phx-click="generate_attendance_form">
                  {if @attendance_form_connected?,
                    do: "Regenerate attendance form",
                    else: "Generate attendance form"}
                </.button>
                <.button
                  :if={@training_activity.attendance_form_id}
                  href={google_form_edit_url(@training_activity.attendance_form_id)}
                  target="_blank"
                  rel="noreferrer"
                  variant="ghost"
                >
                  Manage in Google Forms
                </.button>
              </div>
            </article>

            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Attendance Response Sheet</div>
                  <div class="feature-copy">
                    Google Sheet source used for attendance validation inside open sessions.
                  </div>
                </div>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{connection_tone(@attendance_sheet_connected?)}"
                ]}>
                  {connection_label(@attendance_sheet_connected?)}
                </span>
              </div>

              <div class="mt-4 space-y-2 text-sm text-slate-600">
                <p>Sheet ID: {@training_activity.attendance_sheet_id || "Not configured"}</p>
                <p>Range: {@training_activity.attendance_sheet_range || "Not configured"}</p>
                <p>
                  Last sync: {format_sync_timestamp(
                    @training_activity.attendance_sheet_last_synced_at
                  )}
                </p>
                <p :if={
                  @training_activity.attendance_sheet_id &&
                    !configured?(@training_activity.attendance_sheet_range)
                }>
                  Link a response sheet in Google Forms, then add the range here for attendance sync.
                </p>
              </div>
            </article>

            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Evaluation Workflow</div>
                  <div class="feature-copy">
                    Completion feedback requirement used before certificate processing.
                  </div>
                </div>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{evaluation_tone(@training_activity.evaluation_required)}"
                ]}>
                  {evaluation_label(@training_activity.evaluation_required)}
                </span>
              </div>

              <p class="mt-4 section-copy">
                {evaluation_detail(@training_activity.evaluation_required)}
              </p>

              <div class="mt-4">
                <.button
                  navigate={~p"/trainings/#{@training_activity.id}/completion"}
                  variant="ghost"
                >
                  Review completion rules
                </.button>
              </div>
            </article>

            <article class="feature-card">
              <div class="flex items-start justify-between gap-3">
                <div>
                  <div class="feature-title">Certificate Delivery Folder</div>
                  <div class="feature-copy">
                    Shared document storage for generated artifacts and release workflows.
                  </div>
                </div>
                <span class="portal-chip portal-chip-amber">Planned</span>
              </div>

              <p class="mt-4 section-copy">
                Certificate files are already managed in TRACMS. Direct Google Drive folder automation is the next integration phase.
              </p>

              <div class="mt-4">
                <.button
                  navigate={~p"/certificates/trainings/#{@training_activity.id}"}
                  variant="ghost"
                >
                  Review certificates
                </.button>
              </div>
            </article>
          </div>
        </section>

        <%= if @registration_sync_result do %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Latest result"
              title="Registration sync outcome"
              meta="Review the latest manual synchronization summary."
            />

            <div class="grid gap-4 md:grid-cols-3">
              <div class="feature-card">
                <div class="feature-title">Created intake rows</div>
                <div class="feature-copy">{@registration_sync_result.created_count}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Skipped rows</div>
                <div class="feature-copy">{@registration_sync_result.skipped_count}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Errors</div>
                <div class="feature-copy">{@registration_sync_result.error_count}</div>
              </div>
            </div>
          </section>
        <% end %>

        <section class="content-grid">
          <article class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Current release model"
              title="TRACMS + Google workflow"
              meta="This page organizes the practical hybrid workflow already supported in the system."
            />

            <div class="portal-workflow-list">
              <div class="portal-workflow-item portal-workflow-item-blue">
                <div>
                  <p class="portal-workflow-label">1. Configure collection</p>
                  <p class="portal-workflow-copy">
                    Add approved Google Form links and response-sheet details to the training record.
                    TRACMS can now generate the registration and attendance forms directly.
                  </p>
                </div>
                <span class="portal-workflow-value">{@configured_steps.collection}</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-amber">
                <div>
                  <p class="portal-workflow-label">2. Review registration intake</p>
                  <p class="portal-workflow-copy">
                    Pull Google Sheet responses into the external intake queue, then approve or reject participants in TRACMS.
                  </p>
                </div>
                <span class="portal-workflow-value">{@configured_steps.registration}</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-green">
                <div>
                  <p class="portal-workflow-label">3. Validate attendance</p>
                  <p class="portal-workflow-copy">
                    Open attendance sessions in TRACMS, then sync or manually verify attendance results.
                  </p>
                </div>
                <span class="portal-workflow-value">{@configured_steps.attendance}</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-slate">
                <div>
                  <p class="portal-workflow-label">4. Complete and certify</p>
                  <p class="portal-workflow-copy">
                    Use TRACMS completion rules, evaluation requirements, and certificate delivery records as the official source of truth.
                  </p>
                </div>
                <span class="portal-workflow-value">{@configured_steps.completion}</span>
              </div>
            </div>
          </article>

          <article class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Architecture direction"
              title="What this redesign improves"
              meta="The attached plan is reflected here as an operational control center."
            />

            <div class="space-y-4">
              <div class="feature-card">
                <div class="feature-title">Google handles collection</div>
                <div class="feature-copy">
                  Teachers and personnel can keep using familiar Google Forms instead of learning a separate registration front end.
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">TRACMS handles governance</div>
                <div class="feature-copy">
                  Approval, attendance validation, completion checking, certification, and reporting stay inside the official DepEd Region IX portal.
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Phase 2 is ready</div>
                <div class="feature-copy">
                  Direct Google Forms creation can be added next without changing the core manager workflow because this page already centralizes integration ownership.
                </div>
              </div>
            </div>
          </article>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    load_page(socket, socket.assigns.training_id)
  end

  defp load_page(socket, training_id) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, training_id)

    attendance_sessions =
      Attendance.list_sessions(socket.assigns.current_scope, training_activity.id)

    external_submissions =
      Registrations.list_external_registration_submissions(
        socket.assigns.current_scope,
        training_activity.id
      )

    registration_form_connected? = configured?(training_activity.registration_form_url)
    registration_sheet_connected? = google_sheet_connected?(training_activity, :registration)
    attendance_form_connected? = configured?(training_activity.attendance_form_url)
    attendance_sheet_connected? = google_sheet_connected?(training_activity, :attendance)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:registration_form_connected?, registration_form_connected?)
    |> assign(:registration_sheet_connected?, registration_sheet_connected?)
    |> assign(:attendance_form_connected?, attendance_form_connected?)
    |> assign(:attendance_sheet_connected?, attendance_sheet_connected?)
    |> assign(:summary_cards, summary_cards(training_activity, attendance_sessions))
    |> assign(
      :configured_steps,
      configured_steps(
        training_activity,
        attendance_sessions,
        external_submissions
      )
    )
  end

  defp summary_cards(training_activity, attendance_sessions) do
    [
      summary_card(
        "Configured forms",
        configured_form_count(training_activity),
        "Registration and attendance collection endpoints"
      ),
      summary_card(
        "Configured sheets",
        configured_sheet_count(training_activity),
        "Manual response sources ready for sync"
      ),
      summary_card(
        "Open sessions",
        Enum.count(attendance_sessions, &(&1.status == :open)),
        "Attendance windows currently ready for validation"
      ),
      summary_card(
        "Latest sync",
        latest_sync_label(training_activity),
        "Most recent Google Sheets synchronization on file"
      )
    ]
  end

  defp configured_steps(training_activity, attendance_sessions, external_submissions) do
    %{
      collection: "#{configured_form_count(training_activity)}/2 forms",
      registration:
        "#{Enum.count(external_submissions, &(&1.status == :pending_review))} pending",
      attendance: "#{Enum.count(attendance_sessions, &(&1.status == :open))} open session(s)",
      completion:
        if(training_activity.evaluation_required,
          do: "Evaluation required",
          else: "No evaluation gate"
        )
    }
  end

  defp configured_form_count(training_activity) do
    Enum.count(
      [training_activity.registration_form_url, training_activity.attendance_form_url],
      &configured?/1
    )
  end

  defp configured_sheet_count(training_activity) do
    Enum.count([
      google_sheet_connected?(training_activity, :registration),
      google_sheet_connected?(training_activity, :attendance)
    ])
  end

  defp latest_sync_label(training_activity) do
    [
      training_activity.registration_sheet_last_synced_at,
      training_activity.attendance_sheet_last_synced_at
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] ->
        "Not yet synced"

      timestamps ->
        timestamps
        |> Enum.max_by(&DateTime.to_unix/1)
        |> format_sync_timestamp()
    end
  end

  defp configured?(value) when is_binary(value), do: String.trim(value) != ""
  defp configured?(_value), do: false

  defp google_sheet_connected?(training_activity, :registration) do
    configured?(training_activity.registration_sheet_id) and
      configured?(training_activity.registration_sheet_range)
  end

  defp google_sheet_connected?(training_activity, :attendance) do
    configured?(training_activity.attendance_sheet_id) and
      configured?(training_activity.attendance_sheet_range)
  end

  defp connection_label(true), do: "Connected"
  defp connection_label(false), do: "Needs setup"

  defp connection_tone(true), do: "green"
  defp connection_tone(false), do: "amber"

  defp connection_detail(true, _fallback),
    do: "Official Google Workspace entry point is configured for this training."

  defp connection_detail(false, fallback), do: fallback

  defp evaluation_label(true), do: "TRACMS internal"
  defp evaluation_label(false), do: "Not required"

  defp evaluation_tone(true), do: "blue"
  defp evaluation_tone(false), do: "slate"

  defp evaluation_detail(true) do
    "Participants must complete the TRACMS evaluation step before final completion review."
  end

  defp evaluation_detail(false) do
    "This training does not require a separate evaluation submission before completion."
  end

  defp format_sync_timestamp(nil), do: "Not yet synced"

  defp format_sync_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%b %d, %Y %I:%M %p UTC")
  end

  defp registration_sync_summary(result) do
    "Registration sync completed: #{result.created_count} created, #{result.skipped_count} skipped, #{result.error_count} errors."
  end

  defp registration_sync_error_message(:external_collection_not_enabled) do
    "This training is not configured for an external registration workflow yet."
  end

  defp registration_sync_error_message(:google_sheet_sync_not_configured) do
    "Configure the registration Google Sheet ID and range before syncing."
  end

  defp registration_sync_error_message(:google_sheet_has_no_values) do
    "The registration response sheet does not contain any rows yet."
  end

  defp registration_sync_error_message({:missing_import_headers, headers}) do
    "The registration response sheet is missing required headers: #{Enum.join(headers, ", ")}."
  end

  defp registration_sync_error_message(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp registration_sync_error_message(_reason) do
    "Unable to synchronize the registration response sheet right now."
  end

  defp google_form_error_message(:missing_google_service_account_json) do
    "The GOOGLE_SERVICE_ACCOUNT_JSON environment variable is not configured for Google Forms generation."
  end

  defp google_form_error_message(:invalid_google_service_account_json) do
    "The GOOGLE_SERVICE_ACCOUNT_JSON value is not a valid Google service account JSON document."
  end

  defp google_form_error_message({:google_token_request_failed, _reason}) do
    "TRACMS could not obtain a Google access token for Google Forms generation."
  end

  defp google_form_error_message({:google_form_create_failed, _reason}) do
    "TRACMS could not create the Google Form."
  end

  defp google_form_error_message({:google_form_update_failed, _reason}) do
    "TRACMS created the form shell but could not finish configuring its questions or settings."
  end

  defp google_form_error_message({:google_form_publish_failed, _reason}) do
    "TRACMS created the form but could not publish it for responses."
  end

  defp google_form_error_message({:google_drive_permission_failed, _reason}) do
    "TRACMS created the form but could not share edit access with the current manager account."
  end

  defp google_form_error_message({:google_form_fetch_failed, _reason}) do
    "TRACMS created the form but could not retrieve its final details."
  end

  defp google_form_error_message(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp google_form_error_message(_reason) do
    "Unable to generate the Google Form right now."
  end

  defp google_form_edit_url(form_id), do: "https://docs.google.com/forms/d/#{form_id}/edit"
end
