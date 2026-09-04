defmodule TracmsWeb.TrainingLive.AttendanceIndex do
  use TracmsWeb, :live_view

  alias Tracms.Attendance
  alias Tracms.Attendance.AttendanceSession
  alias Tracms.Registrations
  alias Tracms.Trainings

  @default_filters %{"training_id" => "", "search" => "", "session_id" => "", "view" => "list"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "List of Attendance")
     |> assign(:filters, @default_filters)
     |> assign(:selected_training, nil)
     |> assign(:attendance_session, nil)
     |> assign(:attendance_sessions, [])
     |> assign(:attendance_entries, [])
     |> assign(:attendance_summary_cards, [])
     |> assign(:filter_form, to_form(@default_filters, as: :filters))
     |> assign(:session_form, nil)
     |> assign(:training_directory_caption, "")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters =
      @default_filters
      |> Map.merge(%{
        "training_id" => params["training_id"] || "",
        "search" => params["search"] || "",
        "session_id" => params["session_id"] || "",
        "view" => params["view"] || "list"
      })

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> load_attendance_page()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    updated_filters =
      Map.put(socket.assigns.filters, "search", Map.get(filters, "search", ""))

    {:noreply,
     socket
     |> assign(:filters, updated_filters)
     |> load_attendance_page()}
  end

  @impl true
  def handle_event("validate_session", %{"attendance_session" => params}, socket) do
    changeset =
      socket.assigns.selected_training
      |> build_session(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :session_form, to_form(changeset, as: :attendance_session))}
  end

  def handle_event("create_session", %{"attendance_session" => params}, socket) do
    case Attendance.create_session(
           socket.assigns.current_scope,
           socket.assigns.selected_training.id,
           params
         ) do
      {:ok, attendance_session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Attendance session created successfully.")
         |> push_patch(
           to:
             attendance_workspace_selection_path(
               socket.assigns.selected_training.id,
               attendance_session.id
             )
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :session_form, to_form(changeset, as: :attendance_session))}
    end
  end

  def handle_event("open_session", %{"id" => id}, socket) do
    update_session_status(
      socket,
      id,
      &Attendance.open_session/2,
      "Attendance session is now open."
    )
  end

  def handle_event("close_session", %{"id" => id}, socket) do
    update_session_status(
      socket,
      id,
      &Attendance.close_session/2,
      "Attendance session closed successfully."
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="attendance"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Attendance Management"
          title={if(@selected_training, do: @selected_training.title, else: "List of Attendance")}
          copy={
            if(@selected_training,
              do:
                if(@filters["view"] == "workspace",
                  do: "Create and manage attendance sessions for this training.",
                  else: "Review training details and participant attendance in one place."
                ),
              else: nil
            )
          }
        />

        <.panel
          :if={is_nil(@selected_training)}
          eyebrow="Training directory"
          title="Choose a Training First"
        >
          <.data_table
            id="attendance-training-directory"
            rows={@trainings}
            row_id={fn training -> "attendance-training-#{training.id}" end}
            empty?={@trainings == []}
          >
            <:col :let={training} label="Training Title">
              <div class="portal-cell-title">{training.title}</div>
              <div class="portal-cell-meta">
                {training.resource_speaker || "Facilitator to be assigned"}
              </div>
            </:col>
            <:col :let={training} label="Schedule">
              <div class="portal-cell-title">
                {format_date(training.starts_on)} to {format_date(training.ends_on)}
              </div>
              <div class="portal-cell-meta">
                {schedule_time_label(training.start_time, training.end_time)}
              </div>
            </:col>
            <:col :let={training} label="Venue">{training.venue || "Venue to be announced"}</:col>
            <:col :let={training} label="Status">
              <.badge tone={training_status_tone(training.status)}>
                {Trainings.format_status(training.status)}
              </.badge>
            </:col>
            <:action :let={training}>
              <div class="flex flex-wrap items-center gap-2">
                <.button patch={training_selection_path(training.id)} variant="secondary">
                  View
                </.button>
                <.button patch={attendance_workspace_path(training.id)} variant="ghost">
                  Attendance Workspace
                </.button>
              </div>
            </:action>
            <:empty>
              <.portal_empty_state
                icon="hero-calendar-days"
                title="No trainings available yet"
                copy="Create a training activity first before recording attendance."
              />
            </:empty>
          </.data_table>
          <%= if @trainings != [] do %>
            <p class="mt-4 text-right text-sm text-slate-500">{@training_directory_caption}</p>
          <% end %>
        </.panel>

        <div :if={@selected_training && @filters["view"] == "list"} class="space-y-6">
          <.portal_stat_grid cards={@attendance_summary_cards} />

          <div class="content-grid">
            <.panel title="Participant attendance" class="md:col-span-2">
              <.form
                for={@filter_form}
                id="attendance-filters"
                phx-change="filter"
                class="certificate-records-controls mb-6 flex flex-wrap items-center gap-3"
              >
                <.input
                  field={@filter_form[:search]}
                  type="search"
                  placeholder="Search Participant"
                  aria-label="Search Participant"
                  class="field-input w-full sm:w-96 lg:w-[28rem]"
                />
                <div class="flex flex-wrap items-center gap-3">
                  <.button
                    navigate={registration_management_path(@selected_training.id)}
                    variant="secondary"
                  >
                    Add Participant Manually
                  </.button>
                  <.button href={attendance_export_path(:excel, @filters)} variant="ghost">
                    Export Excel
                  </.button>
                  <.button href={attendance_export_path(:pdf, @filters)} variant="ghost">
                    Export PDF
                  </.button>
                  <.button patch={~p"/attendance"} variant="ghost">Back</.button>
                </div>
              </.form>

              <.data_table
                id="attendance-roster"
                rows={@attendance_entries}
                row_id={fn entry -> "attendance-registration-#{entry.registration.id}" end}
                empty?={@attendance_entries == []}
              >
                <:col :let={entry} label="Participant Name">
                  <div class="portal-cell-title">
                    {Registrations.participant_name(entry.registration)}
                  </div>
                  <div class="portal-cell-meta">
                    {Registrations.participant_email(entry.registration) || "Not provided"}
                  </div>
                </:col>
                <:col :let={entry} label="School, Office, or Organization">
                  {Registrations.participant_organization(entry.registration) || "Not provided"}
                </:col>
                <:col label="Selected Training">
                  <div class="portal-cell-title">{@selected_training.title}</div>
                  <div class="portal-cell-meta">{format_date(@selected_training.starts_on)}</div>
                </:col>
                <:col :let={entry} label="Attendance Status">
                  <.badge tone={attendance_status_tone(entry.record)}>
                    {attendance_status_label(entry.record)}
                  </.badge>
                </:col>
                <:empty>
                  <.portal_empty_state
                    icon="hero-user-group"
                    title="No Participants Found"
                    copy="There are no approved participants matching the current search."
                  />
                </:empty>
              </.data_table>
              <p class="mt-4 text-right text-sm text-slate-500">
                {attendance_roster_caption(@attendance_entries)}
              </p>
            </.panel>
          </div>
        </div>

        <.panel
          :if={@selected_training && @filters["view"] == "workspace"}
          eyebrow="Attendance Workspace"
          title="Manage Attendance Sessions"
        >
          <:actions>
            <.button patch={training_selection_path(@selected_training.id)} variant="ghost">
              Back
            </.button>
            <.button
              type="submit"
              form="attendance-session-form"
              phx-disable-with="Creating Session..."
            >
              Create Session
            </.button>
          </:actions>

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
                  label="Session Name"
                  placeholder="Day 1 - Morning Session"
                  required
                />
              </div>
              <.input field={@session_form[:session_date]} type="date" label="Session Date" required />
              <.input field={@session_form[:starts_at]} type="time" label="Start Time" required />
              <.input field={@session_form[:ends_at]} type="time" label="End Time" required />
            </div>
          </.form>

          <div class="mt-8 border-t border-[var(--tracms-border)] pt-6">
            <%= if @attendance_sessions == [] do %>
              <.portal_empty_state
                icon="hero-calendar-days"
                title="No Attendance Sessions Yet"
                copy="Create the first session to begin attendance tracking."
              />
            <% else %>
              <div class="session-list">
                <.card
                  :for={session <- @attendance_sessions}
                  id={"attendance-session-#{session.id}"}
                  title={session.name}
                  description={
                    "#{format_date(session.session_date)} • #{format_time(session.starts_at)} to #{format_time(session.ends_at)}"
                  }
                  class={[
                    "session-card",
                    session.id == (@attendance_session && @attendance_session.id) &&
                      "session-card-active"
                  ]}
                >
                  <:actions>
                    <.badge tone={session_status_tone(session.status)}>
                      {Attendance.format_status(session.status)}
                    </.badge>
                  </:actions>
                  <.link
                    patch={attendance_workspace_selection_path(@selected_training.id, session.id)}
                    class="session-card-link"
                  >
                    View this attendance session
                  </.link>
                  <:footer>
                    <.button
                      :if={session.status == :draft}
                      type="button"
                      phx-click="open_session"
                      phx-value-id={session.id}
                      phx-disable-with="Opening Session..."
                      variant="secondary"
                    >
                      Open Session
                    </.button>
                    <.button
                      :if={session.status == :open}
                      type="button"
                      phx-click="close_session"
                      phx-value-id={session.id}
                      phx-disable-with="Closing Session..."
                      variant="secondary"
                    >
                      Close Session
                    </.button>
                  </:footer>
                </.card>
              </div>
              <p class="mt-4 text-right text-sm text-slate-500">
                {session_caption(@attendance_sessions)}
              </p>
            <% end %>
          </div>
        </.panel>
      </div>
    </Layouts.app>
    """
  end

  defp load_attendance_page(socket) do
    trainings = Trainings.list_training_activities(socket.assigns.current_scope)
    selected_training_id = normalize_filter_value(socket.assigns.filters["training_id"])

    socket =
      socket
      |> assign(:trainings, trainings)
      |> assign(:training_directory_caption, training_directory_caption(trainings))
      |> assign(:filter_form, to_form(socket.assigns.filters, as: :filters))

    case selected_training_id do
      nil ->
        socket
        |> assign(:selected_training, nil)
        |> assign(:attendance_session, nil)
        |> assign(:attendance_sessions, [])
        |> assign(:attendance_entries, [])
        |> assign(:attendance_summary_cards, [])
        |> assign(:session_form, nil)

      training_id ->
        case Attendance.get_training_attendance(
               socket.assigns.current_scope,
               training_id,
               normalize_filter_value(socket.assigns.filters["session_id"])
             ) do
          {:ok, attendance_view} ->
            attendance_entries =
              Attendance.filter_training_attendance_entries(
                attendance_view.entries,
                socket.assigns.filters["search"]
              )

            socket
            |> assign(:selected_training, attendance_view.training_activity)
            |> assign(:attendance_session, attendance_view.attendance_session)
            |> assign(:attendance_sessions, attendance_view.attendance_sessions)
            |> assign(:attendance_entries, attendance_entries)
            |> assign(
              :attendance_summary_cards,
              attendance_summary_cards(attendance_view.entries)
            )
            |> assign(:session_form, build_session_form(attendance_view.training_activity))

          _other ->
            socket
            |> assign(:selected_training, nil)
            |> assign(:attendance_session, nil)
            |> assign(:attendance_sessions, [])
            |> assign(:attendance_entries, [])
            |> assign(:attendance_summary_cards, [])
            |> assign(:session_form, nil)
        end
    end
  end

  defp normalize_filter_value(value) when value in [nil, ""], do: nil
  defp normalize_filter_value(value), do: value

  defp training_directory_caption(trainings) do
    count = length(trainings)
    "#{count} #{if(count == 1, do: "training", else: "trainings")} ready for attendance review."
  end

  defp attendance_summary_cards(entries) do
    recorded_count = Enum.count(entries, &match?(%{record: %{}}, &1))

    [
      summary_card(
        "Total Participants",
        length(entries),
        "Approved participants in this training"
      ),
      summary_card(
        "Attendance Recorded",
        recorded_count,
        "Participants with a saved attendance status"
      ),
      summary_card(
        "Not Recorded",
        length(entries) - recorded_count,
        "Participants still needing attendance"
      )
    ]
  end

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> :success
      status in [:draft, :pending_division_approval, :pending_region_approval] -> :warning
      status in [:completed, :archived] -> :info
      status == :cancelled -> :danger
      true -> :neutral
    end
  end

  defp schedule_time_label(nil, nil), do: "Time to be announced"
  defp schedule_time_label(start_time, nil), do: "#{format_time(start_time)} start"
  defp schedule_time_label(nil, end_time), do: "Until #{format_time(end_time)}"

  defp schedule_time_label(start_time, end_time) do
    "#{format_time(start_time)} to #{format_time(end_time)}"
  end

  defp training_selection_path(training_id) do
    "/attendance?" <> URI.encode_query(%{"training_id" => training_id})
  end

  defp attendance_workspace_path(training_id) do
    "/attendance?" <> URI.encode_query(%{"training_id" => training_id, "view" => "workspace"})
  end

  defp registration_management_path(training_id) do
    "/registrations?" <>
      URI.encode_query(%{"training_id" => training_id, "view" => "manage", "manual" => "true"})
  end

  defp attendance_workspace_selection_path(training_id, session_id) do
    "/attendance?" <>
      URI.encode_query(%{
        "training_id" => training_id,
        "session_id" => session_id,
        "view" => "workspace"
      })
  end

  defp build_session_form(training_activity, params \\ %{}) do
    params =
      Map.merge(
        %{
          "name" => "",
          "session_date" => training_activity.starts_on || Date.utc_today(),
          "starts_at" => ~T[08:00:00],
          "ends_at" => ~T[17:00:00]
        },
        params
      )

    training_activity
    |> build_session(params)
    |> to_form(as: :attendance_session)
  end

  defp build_session(training_activity, params) do
    Attendance.change_session(
      %AttendanceSession{training_activity_id: training_activity.id},
      params
    )
  end

  defp update_session_status(socket, id, transition, success_message) do
    session = Enum.find(socket.assigns.attendance_sessions, &(&1.id == id))

    case session && transition.(socket.assigns.current_scope, session) do
      {:ok, _attendance_session} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message)
         |> push_patch(
           to: attendance_workspace_selection_path(socket.assigns.selected_training.id, id)
         )}

      {:error, :invalid_transition} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This attendance session cannot be updated in its current status."
         )}

      _ ->
        {:noreply, put_flash(socket, :error, "Unable to update this attendance session.")}
    end
  end

  defp session_caption(attendance_sessions) do
    count = length(attendance_sessions)
    "Showing #{count} attendance #{if(count == 1, do: "session", else: "sessions")}."
  end

  defp session_status_tone(:draft), do: :warning
  defp session_status_tone(:open), do: :success
  defp session_status_tone(:closed), do: :info
  defp session_status_tone(_status), do: :neutral

  defp attendance_status_label(record) do
    case Attendance.manual_status(record) do
      :present -> "Present"
      :absent -> "Absent"
      _status -> "Not Yet Recorded"
    end
  end

  defp attendance_status_tone(record) do
    case Attendance.manual_status(record) do
      :present -> :success
      :absent -> :danger
      _status -> :warning
    end
  end

  defp attendance_roster_caption(entries) do
    count = length(entries)
    "Showing #{count} registered participant#{if(count == 1, do: "", else: "s")}."
  end

  defp attendance_export_path(kind, filters) do
    query =
      filters
      |> Map.take(["training_id", "search"])
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
      |> Map.new()

    case kind do
      :excel -> ~p"/attendance/export/excel?#{query}"
      :pdf -> ~p"/attendance/export/pdf?#{query}"
    end
  end
end
