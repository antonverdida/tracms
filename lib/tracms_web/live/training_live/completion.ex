defmodule TracmsWeb.TrainingLive.Completion do
  use TracmsWeb, :live_view

  alias Tracms.Certificates
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
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Completion summary"
          title={@training_activity.title}
          copy="Review attendance percentage, evaluation submission, and computed completion status."
        >
          <:actions>
            <.button navigate={~p"/trainings/#{@training_activity.id}"} variant="ghost">
              Back to training
            </.button>
            <.button
              navigate={~p"/certificates/trainings/#{@training_activity.id}"}
              variant="ghost"
            >
              Certificates
            </.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="panel portal-list-panel">
          <.portal_panel_header eyebrow="Training rules" title="Completion criteria" />

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
            <div class="feature-card">
              <div class="feature-title">Certificate release rule</div>
              <div class="feature-copy">
                Certificates can be issued after completion is satisfied and no certificate record exists yet.
              </div>
            </div>
          </div>
        </section>

        <section class="panel portal-list-panel">
          <%= if @entries == [] do %>
            <.portal_empty_state
              icon="hero-academic-cap"
              title="No approved participants yet"
              copy="Approve registrations first to begin completion tracking for this training."
            />
          <% else %>
            <.portal_panel_header
              eyebrow="Participant progress"
              title="Completion roster"
              meta={completion_caption(@entries)}
            />

            <div class="data-table-wrap">
              <table class="data-table">
                <thead>
                  <tr>
                    <th>Participant</th>
                    <th>Attendance</th>
                    <th>Evaluation</th>
                    <th>Completion</th>
                    <th>Certificate readiness</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={entry <- @entries}>
                    <td>
                      <div class="portal-cell-title">{participant_name(entry)}</div>
                      <div class="portal-cell-meta">{entry.registration.registrant_user.email}</div>
                    </td>
                    <td>
                      <div>{entry.attendance_percentage}%</div>
                      <div class="portal-cell-meta">
                        {entry.attended_sessions_count} of {entry.total_sessions_count} sessions
                      </div>
                    </td>
                    <td>
                      {evaluation_label(
                        @training_activity.evaluation_required,
                        entry.evaluation_submission
                      )}
                    </td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{completion_status_tone(entry.completion_status)}"
                      ]}>
                        {Evaluations.completion_status_label(entry.completion_status)}
                      </span>
                    </td>
                    <td>
                      <span class={[
                        "portal-chip",
                        "portal-chip-#{certificate_readiness(entry, @certificate_map)}"
                      ]}>
                        {certificate_readiness_label(entry, @certificate_map)}
                      </span>
                      <div class="portal-cell-meta">
                        {certificate_readiness_meta(entry, @certificate_map)}
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
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

    certificate_map =
      entries
      |> Enum.map(& &1.registration.id)
      |> Certificates.list_certificate_map_for_registrations()

    summary = Evaluations.completion_summary(entries)

    socket
    |> assign(:training_activity, training_activity)
    |> assign(:entries, entries)
    |> assign(:summary, summary)
    |> assign(:certificate_map, certificate_map)
    |> assign(:summary_cards, completion_summary_cards(summary, entries, certificate_map))
  end

  defp evaluation_label(false, _submission), do: "Not required"
  defp evaluation_label(true, nil), do: "Pending"
  defp evaluation_label(true, _submission), do: "Submitted"

  defp completion_summary_cards(summary, entries, certificate_map) do
    eligible_for_certificate_count =
      Enum.count(entries, fn entry ->
        entry.completion_status == :completed and
          not Map.has_key?(certificate_map, entry.registration.id)
      end)

    issued_count = map_size(certificate_map)
    incomplete_requirements_count = summary.insufficient_attendance + summary.awaiting_attendance

    [
      summary_card("Completed", summary.completed, "Participants who satisfied all requirements"),
      summary_card(
        "Eligible for certificate",
        eligible_for_certificate_count,
        "Completed participants who still await certificate issuance"
      ),
      summary_card(
        "Issued certificates",
        issued_count,
        "Completed participants who already have certificate records"
      ),
      summary_card(
        "Pending evaluation",
        summary.pending_evaluation,
        "Participants waiting on feedback submission"
      ),
      summary_card(
        "Incomplete requirements",
        incomplete_requirements_count,
        "Attendance tracking or attendance thresholds still block completion"
      )
    ]
  end

  defp completion_caption(entries) do
    count = length(entries)
    "Showing #{count} approved participant #{if(count == 1, do: "record", else: "records")}."
  end

  defp participant_name(entry) do
    entry.registration.registrant_user.full_name || entry.registration.registrant_user.email
  end

  defp completion_status_tone(:completed), do: "green"
  defp completion_status_tone(:pending_evaluation), do: "amber"
  defp completion_status_tone(:insufficient_attendance), do: "rose"
  defp completion_status_tone(:awaiting_attendance), do: "blue"
  defp completion_status_tone(_status), do: "slate"

  defp certificate_readiness_label(entry, certificate_map) do
    cond do
      Map.has_key?(certificate_map, entry.registration.id) -> "Issued"
      entry.completion_status == :completed -> "Eligible for issuance"
      entry.completion_status == :pending_evaluation -> "Pending evaluation"
      entry.completion_status == :insufficient_attendance -> "Insufficient attendance"
      true -> "Awaiting attendance"
    end
  end

  defp certificate_readiness(entry, certificate_map) do
    cond do
      Map.has_key?(certificate_map, entry.registration.id) -> "green"
      entry.completion_status == :completed -> "blue"
      entry.completion_status == :pending_evaluation -> "amber"
      entry.completion_status == :insufficient_attendance -> "rose"
      true -> "slate"
    end
  end

  defp certificate_readiness_meta(entry, certificate_map) do
    case Map.get(certificate_map, entry.registration.id) do
      %{certificate_number: certificate_number} ->
        "Certificate No. #{certificate_number}"

      nil when entry.completion_status == :completed ->
        "Ready for release from the certificate register"

      nil when entry.completion_status == :pending_evaluation ->
        "Evaluation submission is still required"

      nil when entry.completion_status == :insufficient_attendance ->
        "Attendance is below the minimum requirement"

      nil ->
        "Attendance recording is still incomplete"
    end
  end
end
