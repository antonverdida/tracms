defmodule TracmsWeb.TrainingLive.Reports do
  use TracmsWeb, :live_view

  alias Tracms.Reports
  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Reports")
     |> assign(:report, Reports.overview(socket.assigns.current_scope))}
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
          eyebrow="Management Reporting"
          title="Operational Reports"
          copy="Review the training, registration, attendance, and completion position across your authorized scope."
        >
          <:actions>
            <.button navigate={~p"/audit-logs"} variant="ghost">View audit log</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@report.cards} />

        <.panel
          eyebrow="Training Accomplishment"
          title="Training Activity Summary"
          description="Counts reflect records visible within your management scope."
        >
          <.data_table
            id="reports-training-table"
            rows={@report.training_rows}
            row_id={fn row -> "report-training-#{row.training.id}" end}
            empty?={@report.training_rows == []}
          >
            <:col :let={row} label="Training">
              <.link navigate={~p"/trainings/#{row.training.id}"} class="portal-table-link">
                {row.training.title}
              </.link>
            </:col>
            <:col :let={row} label="Status">
              <.badge tone={training_status_tone(row.training.status)}>
                {Trainings.format_status(row.training.status)}
              </.badge>
            </:col>
            <:col :let={row} label="Registrations">{row.registrations}</:col>
            <:col :let={row} label="Approved">{row.approved}</:col>
            <:col :let={row} label="Sessions">{row.sessions}</:col>
            <:col :let={row} label="Completion-ready">{row.completion_ready}</:col>
            <:empty>
              <.portal_empty_state
                icon="hero-chart-bar"
                title="No Training Records Yet"
                copy="Training accomplishment data will appear here once a training activity is created."
              />
            </:empty>
          </.data_table>
        </.panel>

        <section class="grid gap-6 xl:grid-cols-3">
          <.summary_panel
            id="reports-registration-summary"
            eyebrow="Registration Status"
            title="Participant Pipeline"
            rows={@report.registration_statuses}
          />
          <.summary_panel
            id="reports-attendance-summary"
            eyebrow="Attendance Operations"
            title="Session Status"
            rows={@report.attendance_statuses}
          />
          <.summary_panel
            id="reports-completion-summary"
            eyebrow="Completion Readiness"
            title="Participant Outcomes"
            rows={@report.completion_statuses}
          />
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :rows, :list, required: true

  defp summary_panel(assigns) do
    ~H"""
    <.card id={@id} title={@title} description={@eyebrow}>
      <dl class="divide-y divide-[var(--tracms-border)]">
        <div :for={row <- @rows} class="flex items-center justify-between gap-4 py-3">
          <dt class="text-sm font-medium text-[var(--tracms-text-muted)]">{row.label}</dt>
          <dd class="text-lg font-bold text-[var(--tracms-text)]">{row.value}</dd>
        </div>
      </dl>
    </.card>
    """
  end

  defp training_status_tone(status) do
    case status do
      :published -> :success
      :completed -> :success
      :in_progress -> :warning
      :cancelled -> :danger
      :archived -> :neutral
      _ -> :info
    end
  end
end
