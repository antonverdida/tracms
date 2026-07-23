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
      <div class="space-y-6">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="eyebrow">Attendance management</p>
            <h1 class="section-title">{@training_activity.title}</h1>
            <p class="section-copy">
              Create session-based attendance sheets and mark approved participants.
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
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
          </div>
        </div>

        <section class="content-grid">
          <article class="panel">
            <p class="eyebrow">New session</p>
            <h2 class="section-title">Create attendance session</h2>
            <p class="section-copy">
              Use one session per training block, day, or attendance window.
            </p>

            <.form
              for={@session_form}
              id="attendance-session-form"
              phx-change="validate_session"
              phx-submit="create_session"
              class="mt-6"
            >
              <div class="grid gap-5 md:grid-cols-2">
                <div class="md:col-span-2">
                  <.input field={@session_form[:name]} type="text" label="Session name" required />
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
          </article>

          <article class="panel panel-muted">
            <div class="dashboard-section-head">
              <div>
                <p class="eyebrow">Session list</p>
                <h2 class="section-title">Attendance sessions</h2>
              </div>
            </div>

            <%= if @attendance_sessions == [] do %>
              <p class="section-copy">
                Create the first attendance session to begin roster tracking.
              </p>
            <% else %>
              <div class="session-list mt-6">
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
                        {session.session_date} • {format_time(session.starts_at)} to {format_time(
                          session.ends_at
                        )}
                      </p>
                    </.link>

                    <span class="badge-soft">{Attendance.format_status(session.status)}</span>
                  </div>
                </div>
              </div>
            <% end %>
          </article>
        </section>

        <%= if @selected_session do %>
          <section class="panel space-y-5">
            <div class="dashboard-section-head">
              <div>
                <p class="eyebrow">Selected session</p>
                <h2 class="section-title">{@selected_session.name}</h2>
                <p class="section-copy">
                  Only approved registrations appear in this attendance roster.
                </p>
              </div>

              <div class="flex flex-wrap gap-3">
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
                <span class="badge-soft">{Attendance.format_status(@selected_session.status)}</span>
              </div>
            </div>

            <div class="dashboard-summary-grid attendance-summary-grid">
              <article class="dashboard-summary-card">
                <p class="dashboard-summary-label">Present</p>
                <p class="dashboard-summary-value">{@summary.present}</p>
              </article>
              <article class="dashboard-summary-card">
                <p class="dashboard-summary-label">Late</p>
                <p class="dashboard-summary-value">{@summary.late}</p>
              </article>
              <article class="dashboard-summary-card">
                <p class="dashboard-summary-label">Excused</p>
                <p class="dashboard-summary-value">{@summary.excused}</p>
              </article>
              <article class="dashboard-summary-card">
                <p class="dashboard-summary-label">Unmarked</p>
                <p class="dashboard-summary-value">{@summary.unmarked}</p>
              </article>
            </div>

            <%= if @roster == [] do %>
              <p class="section-copy">
                No approved participants are available for attendance yet. Approve registrations first.
              </p>
            <% else %>
              <.table id="attendance-roster" rows={@roster}>
                <:col :let={entry} label="Participant">
                  <div class="font-semibold">{participant_name(entry.registration)}</div>
                  <div class="text-sm text-[var(--tracms-text-muted)]">
                    {entry.registration.registrant_user.email}
                  </div>
                </:col>
                <:col :let={entry} label="Office">
                  {(entry.registration.registrant_user.office &&
                      entry.registration.registrant_user.office.name) || "Not assigned"}
                </:col>
                <:col :let={entry} label="Status">
                  <span class="badge-soft">
                    {if entry.record,
                      do: Attendance.format_status(entry.record.status),
                      else: "Not marked"}
                  </span>
                </:col>
                <:action :let={entry}>
                  <.button
                    phx-click="mark_attendance"
                    phx-value-registration_id={entry.registration.id}
                    phx-value-status="present"
                    variant={attendance_variant(entry.record, :present)}
                    disabled={@selected_session.status != :open}
                  >
                    Present
                  </.button>
                </:action>
                <:action :let={entry}>
                  <.button
                    phx-click="mark_attendance"
                    phx-value-registration_id={entry.registration.id}
                    phx-value-status="late"
                    variant={attendance_variant(entry.record, :late)}
                    disabled={@selected_session.status != :open}
                  >
                    Late
                  </.button>
                </:action>
                <:action :let={entry}>
                  <.button
                    phx-click="mark_attendance"
                    phx-value-registration_id={entry.registration.id}
                    phx-value-status="excused"
                    variant={attendance_variant(entry.record, :excused)}
                    disabled={@selected_session.status != :open}
                  >
                    Excused
                  </.button>
                </:action>
                <:action :let={entry}>
                  <.button
                    phx-click="mark_attendance"
                    phx-value-registration_id={entry.registration.id}
                    phx-value-status="absent"
                    variant={attendance_variant(entry.record, :absent)}
                    disabled={@selected_session.status != :open}
                  >
                    Absent
                  </.button>
                </:action>
              </.table>
            <% end %>
          </section>
        <% else %>
          <section class="panel">
            <h2 class="section-title">No attendance session selected</h2>
            <p class="section-copy">
              Create a session first, then open it when you are ready to record attendance.
            </p>
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

  defp attendance_variant(%{status: status}, status), do: "primary"
  defp attendance_variant(_record, :present), do: "ghost"
  defp attendance_variant(_record, :late), do: "secondary"
  defp attendance_variant(_record, :excused), do: "ghost"
  defp attendance_variant(_record, :absent), do: "danger"

  defp participant_name(registration) do
    registration.registrant_user.full_name || registration.registrant_user.email
  end

  defp format_time(time) do
    Calendar.strftime(time, "%I:%M %p")
  end
end
