defmodule TracmsWeb.TrainingLive.Completion do
  use TracmsWeb, :live_view

  alias Tracms.Evaluations
  alias Tracms.Trainings

  @impl true
  def mount(%{"training_id" => training_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Completion Summary")
     |> assign(:training_id, training_id)
     |> load_page()}
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
            <p class="eyebrow">Completion summary</p>
            <h1 class="section-title">{@training_activity.title}</h1>
            <p class="section-copy">
              Review attendance percentage, evaluation submission, and computed completion status.
            </p>
          </div>
          <div class="flex flex-wrap gap-3">
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
            <.button navigate={~p"/trainings/#{@training_activity.id}/attendance"} variant="ghost">
              Attendance
            </.button>
          </div>
        </div>

        <div class="dashboard-summary-grid">
          <article class="dashboard-summary-card">
            <p class="dashboard-summary-label">Completed</p>
            <p class="dashboard-summary-value">{@summary.completed}</p>
          </article>
          <article class="dashboard-summary-card">
            <p class="dashboard-summary-label">Pending evaluation</p>
            <p class="dashboard-summary-value">{@summary.pending_evaluation}</p>
          </article>
          <article class="dashboard-summary-card">
            <p class="dashboard-summary-label">Insufficient attendance</p>
            <p class="dashboard-summary-value">{@summary.insufficient_attendance}</p>
          </article>
          <article class="dashboard-summary-card">
            <p class="dashboard-summary-label">Awaiting attendance</p>
            <p class="dashboard-summary-value">{@summary.awaiting_attendance}</p>
          </article>
        </div>

        <section class="panel space-y-5">
          <div class="dashboard-section-head">
            <div>
              <p class="eyebrow">Training rules</p>
              <h2 class="section-title">Completion criteria</h2>
            </div>
          </div>

          <div class="dashboard-action-grid">
            <div class="feature-card">
              <div class="feature-title">Minimum attendance</div>
              <div class="feature-copy">
                {@training_activity.minimum_attendance_percentage}% of recorded sessions
              </div>
            </div>
            <div class="feature-card">
              <div class="feature-title">Evaluation required</div>
              <div class="feature-copy">
                {if @training_activity.evaluation_required, do: "Yes", else: "No"}
              </div>
            </div>
          </div>
        </section>

        <section class="panel">
          <%= if @entries == [] do %>
            <h2 class="section-title">No approved participants yet</h2>
            <p class="section-copy">
              Approve registrations first to begin completion tracking for this training.
            </p>
          <% else %>
            <.table id="completion-roster" rows={@entries}>
              <:col :let={entry} label="Participant">
                <div class="font-semibold">
                  {entry.registration.registrant_user.full_name ||
                    entry.registration.registrant_user.email}
                </div>
                <div class="text-sm text-[var(--tracms-text-muted)]">
                  {entry.registration.registrant_user.email}
                </div>
              </:col>
              <:col :let={entry} label="Attendance">
                <div>{entry.attendance_percentage}%</div>
                <div class="text-sm text-[var(--tracms-text-muted)]">
                  {entry.attended_sessions_count} of {entry.total_sessions_count} sessions
                </div>
              </:col>
              <:col :let={entry} label="Evaluation">
                {evaluation_label(@training_activity.evaluation_required, entry.evaluation_submission)}
              </:col>
              <:col :let={entry} label="Completion">
                <span class="badge-soft">
                  {Evaluations.completion_status_label(entry.completion_status)}
                </span>
              </:col>
            </.table>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_page(socket) do
    training_activity =
      Trainings.get_training_activity!(socket.assigns.current_scope, socket.assigns.training_id)

    entries =
      Evaluations.list_training_completion(socket.assigns.current_scope, training_activity.id)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:entries, entries)
    |> assign(:summary, Evaluations.completion_summary(entries))
  end

  defp evaluation_label(false, _submission), do: "Not required"
  defp evaluation_label(true, nil), do: "Pending"
  defp evaluation_label(true, _submission), do: "Submitted"
end
