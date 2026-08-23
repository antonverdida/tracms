defmodule TracmsWeb.TrainingLive.Reports do
  use TracmsWeb, :live_view

  alias Tracms.Attendance
  alias Tracms.Evaluations
  alias Tracms.Registrations
  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> load_reports()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="reports"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Reports"
          title="Training Operations Reports"
          copy="Review accomplishment-style summaries across trainings, registrations, attendance, and completion."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Training Management</.button>
            <.button navigate={~p"/registrations"} variant="ghost">Registrations</.button>
            <.button navigate={~p"/attendance"} variant="ghost">Attendance</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <%= if @training_rows == [] do %>
          <section class="panel portal-list-panel">
            <.portal_empty_state
              icon="hero-chart-bar-square"
              title="No report data available yet"
              copy="Create and publish trainings first so TRACMS can begin building operational reports."
            >
              <:actions>
                <.link
                  navigate={~p"/trainings/new"}
                  class="portal-link-button portal-link-button-primary"
                >
                  Create training
                </.link>
              </:actions>
            </.portal_empty_state>
          </section>
        <% else %>
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Training accomplishment"
              title="Training performance summary"
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Training</th>
                    <th>Schedule</th>
                    <th>Registrations</th>
                    <th>Attendance Sessions</th>
                    <th>Completion Ready</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={row <- @training_rows}>
                    <td>
                      <div class="portal-cell-title">{row.title}</div>
                      <div class="portal-cell-meta">{row.meta}</div>
                    </td>
                    <td>{row.schedule}</td>
                    <td>
                      <div>{row.registration_total}</div>
                      <div class="portal-cell-meta">
                        Approved: {row.approved_total} • Active: {row.active_total}
                      </div>
                    </td>
                    <td>
                      <div>{row.session_total}</div>
                      <div class="portal-cell-meta">
                        Open: {row.open_session_total} • Closed: {row.closed_session_total}
                      </div>
                    </td>
                    <td>
                      <div>{row.completed_total}</div>
                      <div class="portal-cell-meta">
                        Pending eval: {row.pending_evaluation_total}
                      </div>
                    </td>
                    <td>
                      <span class={["portal-chip", "portal-chip-#{row.status_tone}"]}>
                        {row.status_label}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="mt-4 text-right text-sm text-slate-500">{training_caption(@training_rows)}</p>
          </section>

          <section class="content-grid">
            <article class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Registration summary"
                title="Registration Status"
                meta="Current participant decision counts across your scope."
              />

              <div class="portal-workflow-list">
                <div
                  :for={item <- @registration_status_items}
                  class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
                >
                  <div>
                    <p class="portal-workflow-label">{item.label}</p>
                    <p class="portal-workflow-copy">{item.description}</p>
                  </div>
                  <span class="portal-workflow-value">{item.value}</span>
                </div>
              </div>
            </article>

            <article class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Attendance operations"
                title="Attendance Session Summary"
                meta="Session activity across managed trainings."
              />

              <div class="portal-workflow-list">
                <div
                  :for={item <- @attendance_status_items}
                  class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
                >
                  <div>
                    <p class="portal-workflow-label">{item.label}</p>
                    <p class="portal-workflow-copy">{item.description}</p>
                  </div>
                  <span class="portal-workflow-value">{item.value}</span>
                </div>
              </div>
            </article>
          </section>

          <section class="content-grid">
            <article class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Completion readiness"
                title="Completion Summary"
                meta="Readiness to move from attendance and evaluation into final completion records."
              />

              <div class="portal-workflow-list">
                <div
                  :for={item <- @completion_status_items}
                  class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
                >
                  <div>
                    <p class="portal-workflow-label">{item.label}</p>
                    <p class="portal-workflow-copy">{item.description}</p>
                  </div>
                  <span class="portal-workflow-value">{item.value}</span>
                </div>
              </div>
            </article>

            <article class="panel portal-list-panel">
              <.portal_panel_header
                eyebrow="Quick links"
                title="Report Actions"
                meta="Open the connected operational pages behind these summaries."
              />

              <div class="portal-action-grid">
                <.link
                  :for={action <- @report_actions}
                  navigate={action.path}
                  class="portal-action-tile"
                >
                  <div class={["portal-action-icon", "portal-action-icon-#{action.tone}"]}>
                    <.icon name={action.icon} class="size-6" />
                  </div>
                  <div>
                    <h3 class="portal-action-title">{action.title}</h3>
                    <p class="portal-action-copy">{action.copy}</p>
                  </div>
                </.link>
              </div>
            </article>
          </section>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  defp load_reports(socket) do
    scope = socket.assigns.current_scope
    trainings = Trainings.list_training_activities(scope)
    registrations = Registrations.list_manageable_registrations(scope)
    report_rows = build_training_rows(scope, trainings, registrations)
    registration_counts = Enum.frequencies_by(registrations, & &1.status)
    session_counts = Enum.frequencies_by(Enum.flat_map(report_rows, & &1.sessions), & &1.status)
    completion_counts = accumulate_completion_counts(report_rows)

    socket
    |> assign(:training_rows, report_rows)
    |> assign(:summary_cards, summary_cards(report_rows, registrations))
    |> assign(:registration_status_items, registration_status_items(registration_counts))
    |> assign(:attendance_status_items, attendance_status_items(session_counts))
    |> assign(:completion_status_items, completion_status_items(completion_counts))
    |> assign(:report_actions, report_actions(report_rows))
  end

  defp build_training_rows(scope, trainings, registrations) do
    registrations_by_training = Enum.group_by(registrations, & &1.training_activity_id)

    trainings
    |> Enum.map(fn training ->
      training_registrations = Map.get(registrations_by_training, training.id, [])
      sessions = Attendance.list_sessions(scope, training.id)
      completion_entries = Evaluations.list_training_completion(scope, training.id)
      completion_summary = Evaluations.completion_summary(completion_entries)

      %{
        id: training.id,
        title: training.title,
        meta: [training.category, training.venue] |> Enum.reject(&blank?/1) |> Enum.join(" • "),
        schedule: "#{format_date(training.starts_on)} to #{format_date(training.ends_on)}",
        registration_total: length(training_registrations),
        approved_total: Enum.count(training_registrations, &(&1.status == :approved)),
        active_total:
          Enum.count(training_registrations, &(&1.status in [:submitted, :approved, :waitlisted])),
        session_total: length(sessions),
        open_session_total: Enum.count(sessions, &(&1.status == :open)),
        closed_session_total: Enum.count(sessions, &(&1.status == :closed)),
        completed_total: completion_summary.completed,
        pending_evaluation_total: completion_summary.pending_evaluation,
        completion_summary: completion_summary,
        sessions: sessions,
        status_label: Trainings.format_status(training.status),
        status_tone: training_status_tone(training.status)
      }
    end)
  end

  defp summary_cards(report_rows, registrations) do
    all_sessions = Enum.flat_map(report_rows, & &1.sessions)

    unique_participants =
      registrations
      |> Enum.map(& &1.registrant_user_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> length()

    completion_counts = accumulate_completion_counts(report_rows)

    [
      summary_card(
        "Total trainings",
        length(report_rows),
        "Managed activities included in this reporting scope"
      ),
      summary_card(
        "Participants",
        unique_participants,
        "#{length(registrations)} registration records across managed trainings"
      ),
      summary_card(
        "Attendance sessions",
        length(all_sessions),
        "#{Enum.count(all_sessions, &(&1.status == :open))} currently open for attendance"
      ),
      summary_card(
        "Completion ready",
        completion_counts.completed,
        "#{completion_counts.pending_evaluation} still waiting on evaluation submission"
      )
    ]
  end

  defp registration_status_items(counts) do
    [
      workflow_item(
        "Submitted",
        counts[:submitted] || 0,
        "Waiting for review or approval",
        "blue"
      ),
      workflow_item(
        "Approved",
        counts[:approved] || 0,
        "Confirmed for attendance and completion",
        "green"
      ),
      workflow_item(
        "Waitlisted",
        counts[:waitlisted] || 0,
        "Held due to capacity or selection limits",
        "amber"
      ),
      workflow_item("Rejected", counts[:rejected] || 0, "Not accepted into the training", "rose"),
      workflow_item(
        "Withdrawn",
        counts[:withdrawn] || 0,
        "Removed from the active roster",
        "slate"
      )
    ]
  end

  defp attendance_status_items(counts) do
    [
      workflow_item("Draft Sessions", counts[:draft] || 0, "Created but not yet opened", "amber"),
      workflow_item(
        "Open Sessions",
        counts[:open] || 0,
        "Ready for attendance recording",
        "green"
      ),
      workflow_item(
        "Closed Sessions",
        counts[:closed] || 0,
        "Attendance already finalized",
        "blue"
      )
    ]
  end

  defp completion_status_items(counts) do
    [
      workflow_item(
        "Completed",
        counts.completed,
        "Satisfied attendance and evaluation requirements",
        "green"
      ),
      workflow_item(
        "Pending Evaluation",
        counts.pending_evaluation,
        "Attendance met but evaluation still missing",
        "amber"
      ),
      workflow_item(
        "Insufficient Attendance",
        counts.insufficient_attendance,
        "Below the required attendance threshold",
        "rose"
      ),
      workflow_item(
        "Awaiting Attendance",
        counts.awaiting_attendance,
        "Completion cannot be measured yet",
        "blue"
      )
    ]
  end

  defp report_actions([]) do
    [
      quick_action(
        "hero-plus-circle",
        "blue",
        "Create Training",
        "Add a new training activity.",
        ~p"/trainings/new"
      ),
      quick_action(
        "hero-rectangle-stack",
        "green",
        "Manage Trainings",
        "Review schedules and statuses.",
        ~p"/trainings"
      )
    ]
  end

  defp report_actions(rows) do
    first = List.first(rows)

    [
      quick_action(
        "hero-rectangle-stack",
        "green",
        "Manage Trainings",
        "Review the full training list.",
        ~p"/trainings"
      ),
      quick_action(
        "hero-user-group",
        "amber",
        "Registration Review",
        "Open participant review records.",
        ~p"/registrations?training_id=#{first.id}&view=manage"
      ),
      quick_action(
        "hero-document-check",
        "blue",
        "Certificates",
        "Open issued certificate records.",
        ~p"/certificates/trainings/#{first.id}"
      ),
      quick_action(
        "hero-clipboard-document-check",
        "slate",
        "Completion Review",
        "Inspect readiness and completion results.",
        ~p"/trainings/#{first.id}/completion"
      )
    ]
  end

  defp accumulate_completion_counts(rows) do
    Enum.reduce(
      rows,
      %{completed: 0, pending_evaluation: 0, insufficient_attendance: 0, awaiting_attendance: 0},
      fn row, acc ->
        %{
          completed: acc.completed + row.completion_summary.completed,
          pending_evaluation: acc.pending_evaluation + row.completion_summary.pending_evaluation,
          insufficient_attendance:
            acc.insufficient_attendance + row.completion_summary.insufficient_attendance,
          awaiting_attendance:
            acc.awaiting_attendance + row.completion_summary.awaiting_attendance
        }
      end
    )
  end

  defp training_caption(rows) do
    count = length(rows)

    "Showing #{count} training #{if(count == 1, do: "report", else: "reports")} across your current scope."
  end

  defp workflow_item(label, value, description, tone) do
    %{label: label, value: value, description: description, tone: tone}
  end

  defp quick_action(icon, tone, title, copy, path) do
    %{icon: icon, tone: tone, title: title, copy: copy, path: path}
  end

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> "green"
      status in [:draft, :pending_division_approval, :pending_region_approval] -> "amber"
      status in [:completed, :archived] -> "blue"
      true -> "slate"
    end
  end

  defp blank?(value), do: value in [nil, ""]
end
