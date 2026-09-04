defmodule TracmsWeb.TrainingLive.AuditLog do
  use TracmsWeb, :live_view

  alias Tracms.Audit

  @default_filters %{"action" => ""}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Audit Log")
     |> assign(:filters, @default_filters)
     |> assign(:filter_form, to_form(@default_filters, as: :audit_filters))
     |> assign(:audit_logs, [])
     |> assign(:action_options, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = Map.put(@default_filters, "action", params["action"] || "")

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :audit_filters))
     |> assign(:audit_logs, Audit.list(socket.assigns.current_scope, filters))
     |> assign(:action_options, Audit.action_options(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("filter", %{"audit_filters" => filters}, socket) do
    action = Map.get(filters, "action", "")

    {:noreply,
     push_patch(socket,
       to: audit_log_path(action)
     )}
  end

  def handle_event("reset_filters", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/audit-logs")}
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
          eyebrow="Security And Oversight"
          title="Audit Log"
          copy="Review sensitive actions recorded within your authorized training scope."
        >
          <:actions>
            <.button navigate={~p"/reports"} variant="ghost">Back to reports</.button>
          </:actions>
        </.portal_page_header>

        <.panel
          eyebrow="Recorded Activity"
          title="Recent Audit Events"
          description="The most recent 100 entries are shown."
        >
          <.form for={@filter_form} id="audit-log-filter-form" phx-change="filter">
            <div class="flex flex-wrap items-end gap-3 pb-5">
              <div class="min-w-60 flex-1">
                <.input
                  field={@filter_form[:action]}
                  type="select"
                  label="Action"
                  prompt="All actions"
                  options={Enum.map(@action_options, &{format_action(&1), &1})}
                />
              </div>
              <.button type="button" phx-click="reset_filters" variant="ghost">Reset</.button>
            </div>
          </.form>

          <.data_table
            id="audit-log-table"
            rows={@audit_logs}
            row_id={fn audit_log -> "audit-log-#{audit_log.id}" end}
            empty?={@audit_logs == []}
          >
            <:col :let={audit_log} label="When">
              <span class="whitespace-nowrap text-sm text-[var(--tracms-text-muted)]">
                {format_timestamp(audit_log.inserted_at)}
              </span>
            </:col>
            <:col :let={audit_log} label="Actor">{actor_name(audit_log)}</:col>
            <:col :let={audit_log} label="Action">
              <.badge tone={:info}>{format_action(audit_log.action)}</.badge>
            </:col>
            <:col :let={audit_log} label="Training">{training_title(audit_log)}</:col>
            <:col :let={audit_log} label="Details">{audit_summary(audit_log)}</:col>
            <:empty>
              <.portal_empty_state
                icon="hero-clipboard-document-check"
                title="No Audit Events Found"
                copy="Sensitive registration, attendance, and certificate actions will appear here as they occur."
              />
            </:empty>
          </.data_table>
        </.panel>
      </div>
    </Layouts.app>
    """
  end

  defp audit_log_path(""), do: ~p"/audit-logs"
  defp audit_log_path(action), do: ~p"/audit-logs?#{%{action: action}}"

  defp format_action(action) do
    action
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp actor_name(%{actor_user: %{full_name: name}}) when is_binary(name) and name != "", do: name
  defp actor_name(%{actor_user: %{email: email}}) when is_binary(email), do: email
  defp actor_name(_audit_log), do: "Account removed"

  defp training_title(%{training_activity: %{title: title}}) when is_binary(title), do: title
  defp training_title(_audit_log), do: "Not linked to a training"

  defp audit_summary(%{action: "registration_reviewed", metadata: metadata}) do
    "Status: #{metadata["from_status"]} to #{metadata["to_status"]}"
  end

  defp audit_summary(%{action: action, metadata: %{"status" => status}})
       when action in ["attendance_marked", "attendance_updated"],
       do: "Attendance status: #{status}"

  defp audit_summary(%{metadata: %{"certificate_number" => certificate_number}}),
    do: "Certificate no. #{certificate_number}"

  defp audit_summary(_audit_log), do: "Recorded system action"

  defp format_timestamp(%DateTime{} = value),
    do: Calendar.strftime(value, "%b %d, %Y %I:%M %p UTC")

  defp format_timestamp(_value), do: "Not available"
end
