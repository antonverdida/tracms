defmodule TracmsWeb.TrainingLive.Attendance do
  use TracmsWeb, :live_view

  alias Tracms.Attendance
  alias Tracms.Attendance.AttendanceSession
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Attendance")
     |> assign(:training_id, training_id)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, load_page(socket, params["session_id"])}
  end

  @impl true
  def handle_event("validate_session", %{"attendance_session" => params}, socket) do
    changeset =
      socket.assigns.training_activity
      |> build_session(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :session_form, to_form(changeset, as: "attendance_session"))}
  end

  def handle_event("create_session", %{"attendance_session" => params}, socket) do
    case Attendance.create_session(
           socket.assigns.current_scope,
           socket.assigns.training_id,
           params
         ) do
      {:ok, attendance_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance session created successfully.")
         |> push_patch(to: attendance_path(socket.assigns.training_id, attendance_session.id))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :session_form, to_form(changeset, as: "attendance_session"))}
    end
  end

  def handle_event("open_session", %{"id" => id}, socket) do
    session = Enum.find(socket.assigns.attendance_sessions, &(&1.id == id))

    case session && Attendance.open_session(socket.assigns.current_scope, session) do
      {:ok, _attendance_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance session is now open.")
         |> push_patch(to: attendance_path(socket.assigns.training_id, id))}

      {:error, :invalid_transition} ->
        {:noreply, put_flash(socket, :error, "Only draft sessions can be opened.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to open this attendance session.")}
    end
  end

  def handle_event("close_session", %{"id" => id}, socket) do
    session = Enum.find(socket.assigns.attendance_sessions, &(&1.id == id))

    case session && Attendance.close_session(socket.assigns.current_scope, session) do
      {:ok, _attendance_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance session closed successfully.")
         |> push_patch(to: attendance_path(socket.assigns.training_id, id))}

      {:error, :invalid_transition} ->
        {:noreply, put_flash(socket, :error, "Only open sessions can be closed.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to close this attendance session.")}
    end
  end

  def handle_event("sync_google_sheet_attendance", %{"id" => id}, socket) do
    case Attendance.sync_session_attendance_from_google_sheet(socket.assigns.current_scope, id) do
      {:ok, result} ->
        {:noreply,
         socket
         |> put_flash(:info, attendance_sync_flash(result))
         |> load_page(id)
         |> assign(:google_sheet_sync_result, result)}

      {:error, :session_not_open} ->
        {:noreply, put_flash(socket, :error, "Open the attendance session before syncing.")}

      {:error, :google_sheet_sync_not_configured} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Configure the attendance Google Sheet ID and range on the training record first."
         )}

      {:error, {:missing_attendance_sync_headers, headers}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Google Sheet is missing required headers: #{Enum.join(headers, ", ")}."
         )}

      {:error, :google_sheet_has_no_values} ->
        {:noreply,
         put_flash(socket, :error, "The attendance Google Sheet does not contain any rows yet.")}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Unable to sync attendance right now: #{format_sync_error(reason)}."
         )}
    end
  end

  def handle_event(
        "mark_attendance",
        %{"registration_id" => registration_id, "status" => status},
        socket
      ) do
    case Attendance.mark_attendance(
           socket.assigns.current_scope,
           socket.assigns.selected_session.id,
           registration_id,
           %{status: status}
         ) do
      {:ok, _attendance_record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance updated successfully.")
         |> load_page(socket.assigns.selected_session.id)}

      {:error, :session_not_open} ->
        {:noreply, put_flash(socket, :error, "Open the session before recording attendance.")}

      {:error, :registration_not_approved} ->
        {:noreply, put_flash(socket, :error, "Only approved participants can be marked.")}

      {:error, %Ecto.Changeset{}} ->
        {:noreply, put_flash(socket, :error, "Unable to save the attendance status.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update attendance right now.")}
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
          eyebrow="Attendance management"
          title={@training_activity.title}
          copy="Create session-based attendance sheets and mark approved participants."
        >
          <:actions>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/integrations"}
              variant="ghost"
            >
              Google Workspace
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/registrations"}
              variant="ghost"
            >
              View registrations
            </.button>
            <.button
              navigate={~p"/trainings/#{@training_activity.id}/completion"}
              variant="ghost"
            >
              Completion
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="content-grid">
          <article class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="New session"
              title="Create attendance session"
              meta="Use one session per training block, day, or attendance window."
            />

            <.form
              for={@session_form}
              id="attendance-session-form"
              phx-change="validate_session"
              phx-submit="create_session"
              class="mt-6"
            >
              <div class="grid gap-5 md:grid-cols-2">
                <div class="md:col-span-2">
                  <.input
                    field={@session_form[:name]}
                    type="text"
                    label="Session name"
                    placeholder="Day 1 - Morning Session"
                    required
                  />
                </div>
                <.input
                  field={@session_form[:session_date]}
                  type="date"
                  label="Session date"
                  required
                />
                <.input field={@session_form[:starts_at]} type="time" label="Start time" required />
                <.input field={@session_form[:ends_at]} type="time" label="End time" required />
              </div>

              <div class="mt-6 flex justify-end">
                <.button phx-disable-with="Creating session...">Create session</.button>
              </div>
            </.form>

            <div class="mt-6 dashboard-action-grid">
              <div class="feature-card">
                <div class="feature-title">Attendance method</div>
                <div class="feature-copy">{@training_activity.attendance_monitoring_method}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Recommended session naming</div>
                <div class="feature-copy">
                  Day 1 - Morning Session, Day 1 - Afternoon Session, Day 2 - Opening Program
                </div>
              </div>
            </div>

            <p class="mt-4 section-copy">
              Attendance recording in this release remains manager-assisted even when the training
              record is configured for QR-based monitoring.
            </p>
          </article>

          <article class="panel panel-muted portal-list-panel">
            <.portal_panel_header
              eyebrow="Session list"
              title="Attendance sessions"
              meta={session_caption(@attendance_sessions)}
            />

            <%= if @attendance_sessions == [] do %>
              <.portal_empty_state
                icon="hero-calendar-days"
                title="No attendance sessions yet"
                copy="Create the first attendance session to begin roster tracking."
              />
            <% else %>
              <div class="session-list">
                <div
                  :for={session <- @attendance_sessions}
                  class={[
                    "feature-card session-card",
                    session.id == (@selected_session && @selected_session.id) && "session-card-active"
                  ]}
                >
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <.link
                      patch={attendance_path(@training_activity.id, session.id)}
                      class="session-card-link"
                    >
                      <p class="feature-title">{session.name}</p>
                      <p class="feature-copy">
                        {format_date(session.session_date)} • {format_time(session.starts_at)} to {format_time(
                          session.ends_at
                        )}
                      </p>
                    </.link>

                    <span class={["portal-chip", "portal-chip-#{session_status_tone(session.status)}"]}>
                      {Attendance.format_status(session.status)}
                    </span>
                  </div>
                </div>
              </div>
            <% end %>
          </article>
        </section>

        <%= if @selected_session do %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Selected session"
              title={@selected_session.name}
              meta={selected_session_meta(@selected_session)}
            >
              <:actions>
                <.button
                  :if={attendance_sync_available?(@training_activity, @selected_session)}
                  phx-click="sync_google_sheet_attendance"
                  phx-value-id={@selected_session.id}
                  variant="secondary"
                >
                  Sync Google Sheet
                </.button>
                <.button
                  :if={@selected_session.status == :draft}
                  phx-click="open_session"
                  phx-value-id={@selected_session.id}
                >
                  Open session
                </.button>
                <.button
                  :if={@selected_session.status == :open}
                  phx-click="close_session"
                  phx-value-id={@selected_session.id}
                  variant="secondary"
                >
                  Close session
                </.button>
                <span class={[
                  "portal-chip",
                  "portal-chip-#{session_status_tone(@selected_session.status)}"
                ]}>
                  {Attendance.format_status(@selected_session.status)}
                </span>
              </:actions>
            </.portal_panel_header>

            <p class="section-copy">
              Only approved registrations appear in this attendance roster.
            </p>

            <.portal_stat_grid cards={@selected_session_cards} />

            <div class="mt-6 dashboard-action-grid">
              <div class="feature-card">
                <div class="feature-title">Attendance Google Sheet ID</div>
                <div class="feature-copy">
                  {@training_activity.attendance_sheet_id || "Not configured"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Attendance range</div>
                <div class="feature-copy">
                  {@training_activity.attendance_sheet_range || "Not configured"}
                </div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Last attendance sync</div>
                <div class="feature-copy">
                  {format_sync_timestamp(@training_activity.attendance_sheet_last_synced_at)}
                </div>
              </div>
            </div>

            <%= if @google_sheet_sync_result do %>
              <div class="mt-6 rounded-[28px] border border-slate-200 bg-slate-50/80 p-5 shadow-sm">
                <div class="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p class="text-sm font-semibold uppercase tracking-[0.24em] text-slate-500">
                      Latest Sync Result
                    </p>
                    <p class="mt-2 text-base font-semibold text-slate-900">
                      {@google_sheet_sync_result.updated_count} attendance records updated
                    </p>
                  </div>
                  <div class="flex flex-wrap gap-3 text-sm text-slate-600">
                    <span class="portal-chip portal-chip-green">
                      Updated: {@google_sheet_sync_result.updated_count}
                    </span>
                    <span class="portal-chip portal-chip-amber">
                      Skipped rows: {@google_sheet_sync_result.skipped_count}
                    </span>
                    <span class="portal-chip portal-chip-rose">
                      Errors: {@google_sheet_sync_result.error_count}
                    </span>
                  </div>
                </div>

                <%= if @google_sheet_sync_result.errors != [] do %>
                  <div class="mt-4 rounded-3xl border border-rose-200 bg-white p-4">
                    <p class="text-sm font-semibold text-rose-700">Rows needing review</p>
                    <ul class="mt-3 space-y-2 text-sm text-slate-600">
                      <li :for={error <- Enum.take(@google_sheet_sync_result.errors, 3)}>
                        Row {error.row}: {error.message}
                      </li>
                    </ul>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class="mt-6 portal-workflow-list">
              <div class="portal-workflow-item portal-workflow-item-amber">
                <div>
                  <p class="portal-workflow-label">Late</p>
                  <p class="portal-workflow-copy">
                    Participants who attended but were marked late for the selected session.
                  </p>
                </div>
                <span class="portal-workflow-value">{@summary.late}</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-blue">
                <div>
                  <p class="portal-workflow-label">Excused</p>
                  <p class="portal-workflow-copy">
                    Participants with an excused attendance record for this session.
                  </p>
                </div>
                <span class="portal-workflow-value">{@summary.excused}</span>
              </div>
              <div class="portal-workflow-item portal-workflow-item-slate">
                <div>
                  <p class="portal-workflow-label">Unmarked</p>
                  <p class="portal-workflow-copy">
                    Approved participants who still need an attendance decision.
                  </p>
                </div>
                <span class="portal-workflow-value">{@summary.unmarked}</span>
              </div>
            </div>

            <%= if @roster == [] do %>
              <.portal_empty_state
                icon="hero-user-group"
                title="No approved participants available"
                copy="Approve registrations first before recording attendance for this session."
              />
            <% else %>
              <div class="data-table-wrap">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Participant</th>
                      <th>Office</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={entry <- @roster}>
                      <td>
                        <div class="portal-cell-title">{participant_name(entry.registration)}</div>
                        <div class="portal-cell-meta">
                          {entry.registration.registrant_user.email}
                        </div>
                      </td>
                      <td>
                        {(entry.registration.registrant_user.office &&
                            entry.registration.registrant_user.office.name) || "Not assigned"}
                      </td>
                      <td>
                        <span class={[
                          "portal-chip",
                          "portal-chip-#{attendance_status_tone(entry.record)}"
                        ]}>
                          {attendance_status_label(entry.record)}
                        </span>
                      </td>
                      <td>
                        <div class="flex flex-wrap gap-2">
                          <.button
                            phx-click="mark_attendance"
                            phx-value-registration_id={entry.registration.id}
                            phx-value-status="present"
                            variant={attendance_variant(entry.record, :present)}
                            disabled={@selected_session.status != :open}
                          >
                            Present
                          </.button>
                          <.button
                            phx-click="mark_attendance"
                            phx-value-registration_id={entry.registration.id}
                            phx-value-status="late"
                            variant={attendance_variant(entry.record, :late)}
                            disabled={@selected_session.status != :open}
                          >
                            Late
                          </.button>
                          <.button
                            phx-click="mark_attendance"
                            phx-value-registration_id={entry.registration.id}
                            phx-value-status="excused"
                            variant={attendance_variant(entry.record, :excused)}
                            disabled={@selected_session.status != :open}
                          >
                            Excused
                          </.button>
                          <.button
                            phx-click="mark_attendance"
                            phx-value-registration_id={entry.registration.id}
                            phx-value-status="absent"
                            variant={attendance_variant(entry.record, :absent)}
                            disabled={@selected_session.status != :open}
                          >
                            Absent
                          </.button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            <% end %>
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-clipboard-document-check"
              title="No attendance session selected"
              copy="Create a session first, then open it when you are ready to record attendance."
            />
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket, requested_session_id) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, socket.assigns.training_id)

    attendance_sessions =
      Attendance.list_sessions(socket.assigns.current_scope, training_activity.id)

    selected_session = pick_selected_session(attendance_sessions, requested_session_id)

    roster =
      if selected_session,
        do: Attendance.list_session_roster(socket.assigns.current_scope, selected_session.id),
        else: []

    summary = Attendance.roster_summary(roster)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:attendance_sessions, attendance_sessions)
    |> assign(:selected_session, selected_session)
    |> assign(:roster, roster)
    |> assign(:summary, summary)
    |> assign(:google_sheet_sync_result, nil)
    |> assign(:summary_cards, attendance_summary_cards(attendance_sessions, roster))
    |> assign(:selected_session_cards, selected_session_cards(summary, roster))
    |> assign(:session_form, build_session_form(training_activity))
  end

  defp build_session_form(training_activity, params \\ %{}) do
    params =
      Map.merge(
        %{
          "name" => "",
          "session_date" => training_activity.starts_on,
          "starts_at" => ~T[08:00:00],
          "ends_at" => ~T[17:00:00]
        },
        params
      )

    training_activity
    |> build_session(params)
    |> to_form(as: "attendance_session")
  end

  defp build_session(training_activity, params) do
    Attendance.change_session(
      %AttendanceSession{training_activity_id: training_activity.id},
      params
    )
  end

  defp pick_selected_session(attendance_sessions, requested_session_id) do
    Enum.find(attendance_sessions, &(&1.id == requested_session_id)) ||
      List.first(attendance_sessions)
  end

  defp attendance_path(training_id, nil), do: ~p"/trainings/#{training_id}/attendance"

  defp attendance_path(training_id, session_id) do
    ~p"/trainings/#{training_id}/attendance?session_id=#{session_id}"
  end

  defp attendance_summary_cards(attendance_sessions, roster) do
    [
      summary_card(
        "Total sessions",
        length(attendance_sessions),
        "Attendance windows for this training"
      ),
      summary_card(
        "Open sessions",
        Enum.count(attendance_sessions, &(&1.status == :open)),
        "Currently available for attendance marking"
      ),
      summary_card(
        "Closed sessions",
        Enum.count(attendance_sessions, &(&1.status == :closed)),
        "Completed attendance sheets"
      ),
      summary_card(
        "Approved roster",
        length(roster),
        "Participants available in the selected roster"
      )
    ]
  end

  defp selected_session_cards(summary, roster) do
    [
      summary_card(
        "Total participants",
        length(roster),
        "Approved participants in this attendance roster"
      ),
      summary_card("Present today", summary.present, "Participants marked as present"),
      summary_card(
        "Attendance rate",
        "#{attendance_rate(summary, roster)}%",
        "Present, late, and excused records counted as attended"
      ),
      summary_card("Absent", summary.absent, "Participants marked absent for this session")
    ]
  end

  defp session_caption(attendance_sessions) do
    count = length(attendance_sessions)
    "Showing #{count} attendance #{if(count == 1, do: "session", else: "sessions")}."
  end

  defp selected_session_meta(session) do
    "#{format_date(session.session_date)} • #{format_time(session.starts_at)} to #{format_time(session.ends_at)}"
  end

  defp attendance_variant(%{status: status}, status), do: "primary"
  defp attendance_variant(_record, :present), do: "ghost"
  defp attendance_variant(_record, :late), do: "secondary"
  defp attendance_variant(_record, :excused), do: "ghost"
  defp attendance_variant(_record, :absent), do: "danger"

  defp attendance_status_label(nil), do: "Not marked"
  defp attendance_status_label(record), do: Attendance.format_status(record.status)

  defp attendance_status_tone(nil), do: "slate"
  defp attendance_status_tone(%{status: :present}), do: "green"
  defp attendance_status_tone(%{status: :late}), do: "amber"
  defp attendance_status_tone(%{status: :excused}), do: "blue"
  defp attendance_status_tone(%{status: :absent}), do: "rose"
  defp attendance_status_tone(_record), do: "slate"

  defp session_status_tone(:draft), do: "amber"
  defp session_status_tone(:open), do: "green"
  defp session_status_tone(:closed), do: "blue"
  defp session_status_tone(_status), do: "slate"

  defp attendance_rate(_summary, []), do: 0

  defp attendance_rate(summary, roster) do
    attended_count = summary.present + summary.late + summary.excused
    round(attended_count * 100 / length(roster))
  end

  defp attendance_sync_available?(training_activity, selected_session) do
    selected_session.status == :open and
      is_binary(training_activity.attendance_sheet_id) and
      training_activity.attendance_sheet_id != "" and
      is_binary(training_activity.attendance_sheet_range) and
      training_activity.attendance_sheet_range != ""
  end

  defp attendance_sync_flash(result) do
    "Attendance sync completed: #{result.updated_count} updated, #{result.skipped_count} skipped, #{result.error_count} errors."
  end

  defp format_sync_timestamp(nil), do: "Not yet synced"

  defp format_sync_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%b %d, %Y %I:%M %p UTC")
  end

  defp format_sync_error(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  defp format_sync_error(reason), do: inspect(reason)

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end
end
