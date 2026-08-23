defmodule TracmsWeb.TrainingLive.Show do
  use TracmsWeb, :live_view

  alias Tracms.Trainings

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    training_activity = Trainings.get_training_activity!(socket.assigns.current_scope, id)

    {:noreply,
     socket
     |> assign(:page_title, training_activity.title)
     |> assign(:training_activity, training_activity)}
  end

  @impl true
  def handle_event("update_training_status", %{"status" => status}, socket) do
    case delivery_status_target(status) do
      nil ->
        {:noreply, put_flash(socket, :error, "That training status is not available.")}

      target_status ->
        case Trainings.update_training_status(
               socket.assigns.current_scope,
               socket.assigns.training_activity,
               target_status
             ) do
          {:ok, training_activity} ->
            {:noreply,
             socket
             |> assign(:training_activity, training_activity)
             |> put_flash(
               :info,
               "Training status updated to #{Trainings.format_status(target_status)}."
             )}

          {:error, :invalid_transition} ->
            {:noreply, put_flash(socket, :error, "This training cannot move to that status yet.")}

          _other ->
            {:noreply,
             put_flash(socket, :error, "Unable to update the training status right now.")}
        end
    end
  end

  def handle_event("advance_training", _params, socket) do
    case Trainings.advance_training_activity(
           socket.assigns.current_scope,
           socket.assigns.training_activity
         ) do
      {:ok, training_activity} ->
        {:noreply,
         socket
         |> assign(:training_activity, training_activity)
         |> put_flash(
           :info,
           "Training status updated to #{Trainings.format_status(training_activity.status)}."
         )}

      {:error, :invalid_transition} ->
        {:noreply, put_flash(socket, :error, "This training cannot advance in the workflow yet.")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(socket, :error, "You do not have permission to advance this training.")}

      _other ->
        {:noreply, put_flash(socket, :error, "Unable to update the training status right now.")}
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
          eyebrow="Training details"
          title={@training_activity.title}
          copy="Review the complete record and its delivery requirements."
        >
          <:actions>
            <.button navigate={~p"/trainings"} variant="ghost">Back to Trainings</.button>
            <.button
              :if={Trainings.editable?(@training_activity)}
              navigate={~p"/trainings/#{@training_activity.id}/edit"}
              variant="secondary"
            >
              Edit Training
            </.button>
            <.button
              :if={Trainings.next_action_label(@current_scope, @training_activity)}
              type="button"
              phx-click="advance_training"
              variant="secondary"
            >
              {Trainings.next_action_label(@current_scope, @training_activity)}
            </.button>
            <.button
              :if={@training_activity.status in [:published, :registration_closed]}
              type="button"
              phx-click="update_training_status"
              phx-value-status="in_progress"
              variant="secondary"
            >
              Mark as Ongoing
            </.button>
            <.button
              :if={@training_activity.status == :in_progress}
              type="button"
              phx-click="update_training_status"
              phx-value-status="completed"
              variant="secondary"
            >
              Mark as Completed
            </.button>
          </:actions>
        </.portal_page_header>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Overview"
            title="Training information"
            meta="Schedule, venue, and registration readiness."
          />

          <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <.detail_card label="Delivery Status">
              <span class={[
                "portal-chip",
                "portal-chip-#{training_status_tone(@training_activity.status)}"
              ]}>
                {Trainings.format_status(@training_activity.status)}
              </span>
              <span class="mt-2 block text-xs font-normal text-slate-500">
                {status_guidance(@training_activity.status)}
              </span>
            </.detail_card>
            <.detail_card label="Schedule">{training_schedule(@training_activity)}</.detail_card>
            <.detail_card label="Venue">
              {display_value(@training_activity.venue)}
              <span class="block text-xs font-normal text-slate-500">
                {display_value(@training_activity.venue_address, "Address to be announced")}
              </span>
            </.detail_card>
            <.detail_card label="Modality">
              {format_modality(@training_activity.modality)}
            </.detail_card>
            <.detail_card label="Duration">
              {@training_activity.total_hours} training hour(s)
            </.detail_card>
            <.detail_card label="Capacity">{capacity_label(@training_activity)}</.detail_card>
            <.detail_card label="Registration Opens">
              {format_date(@training_activity.registration_opens_on)}
            </.detail_card>
            <.detail_card label="Registration Deadline">
              {format_datetime(@training_activity.registration_deadline)}
            </.detail_card>
            <.detail_card label="Organizer">
              {display_value(@training_activity.organizer)}
            </.detail_card>
            <.detail_card label="Resource Speaker">
              {display_value(@training_activity.resource_speaker, "To be assigned")}
            </.detail_card>
          </div>
        </section>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Training narrative"
            title="Purpose and participants"
            meta="The official context for this activity."
          />

          <div class="grid gap-4 xl:grid-cols-2">
            <.detail_card label="Description">
              <span class="whitespace-pre-line">{display_value(@training_activity.description)}</span>
            </.detail_card>
            <.detail_card label="Objectives">
              <span class="whitespace-pre-line">{display_value(@training_activity.objectives)}</span>
            </.detail_card>
            <.detail_card label="Target Participants">
              {display_value(@training_activity.target_participants)}
            </.detail_card>
            <.detail_card label="Participant Qualification">
              {display_value(@training_activity.participant_qualification)}
            </.detail_card>
            <.detail_card label="Category">{display_value(@training_activity.category)}</.detail_card>
            <.detail_card label="Training Type">
              {display_value(@training_activity.training_type)}
            </.detail_card>
          </div>
        </section>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Operations"
            title="Delivery and completion settings"
            meta="Requirements used for attendance and certificate processing."
          />

          <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <.detail_card label="Attendance Monitoring">
              {display_value(@training_activity.attendance_monitoring_method)}
            </.detail_card>
            <.detail_card label="Minimum Attendance">
              {@training_activity.minimum_attendance_percentage}%
            </.detail_card>
            <.detail_card label="Evaluation Required">
              {if @training_activity.evaluation_required, do: "Yes", else: "No"}
            </.detail_card>
            <.detail_card label="Certificate Type">
              {display_value(@training_activity.certificate_type)}
            </.detail_card>
            <.detail_card label="Registration Form">
              {configured_label(@training_activity.registration_form_url)}
            </.detail_card>
            <.detail_card label="Attendance Form">
              {configured_label(@training_activity.attendance_form_url)}
            </.detail_card>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  slot :inner_block, required: true

  defp detail_card(assigns) do
    ~H"""
    <article class="feature-card">
      <div class="feature-title">{@label}</div>
      <div class="feature-copy">{render_slot(@inner_block)}</div>
    </article>
    """
  end

  defp training_schedule(training) do
    "#{format_date(training.starts_on)} to #{format_date(training.ends_on)} - " <>
      schedule_time_label(training.start_time, training.end_time)
  end

  defp schedule_time_label(nil, nil), do: "Time to be announced"
  defp schedule_time_label(start_time, nil), do: "#{format_time(start_time)} start"
  defp schedule_time_label(nil, end_time), do: "Until #{format_time(end_time)}"

  defp schedule_time_label(start_time, end_time),
    do: "#{format_time(start_time)} to #{format_time(end_time)}"

  defp capacity_label(%{max_capacity: nil}), do: "Not specified"
  defp capacity_label(%{max_capacity: capacity}), do: "#{capacity} participants"

  defp configured_label(nil), do: "Not configured"
  defp configured_label(""), do: "Not configured"
  defp configured_label(_url), do: "Configured"

  defp display_value(value, fallback \\ "Not specified")
  defp display_value(nil, fallback), do: fallback
  defp display_value("", fallback), do: fallback
  defp display_value(value, _fallback), do: value

  defp training_status_tone(status) do
    cond do
      status in [:published, :registration_closed, :in_progress] -> "green"
      status in [:draft, :pending_division_approval, :pending_region_approval] -> "amber"
      status in [:completed, :archived] -> "blue"
      status == :cancelled -> "rose"
      true -> "slate"
    end
  end

  defp delivery_status_target("in_progress"), do: :in_progress
  defp delivery_status_target("completed"), do: :completed
  defp delivery_status_target(_status), do: nil

  defp status_guidance(:published),
    do: "Registration is open. Mark the training as ongoing when delivery starts."

  defp status_guidance(:registration_closed),
    do: "Registration is closed. Mark the training as ongoing when delivery starts."

  defp status_guidance(:in_progress), do: "The training is currently being delivered."

  defp status_guidance(:completed),
    do: "Delivery is finished. Attendance and certificates can now be finalized."

  defp status_guidance(:cancelled), do: "This training will not be delivered."
  defp status_guidance(:archived), do: "This training is retained for records only."
  defp status_guidance(_status), do: "Complete the approval workflow before delivery can begin."
end
