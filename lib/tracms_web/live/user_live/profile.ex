defmodule TracmsWeb.UserLive.Profile do
  use TracmsWeb, :live_view

  alias Tracms.Accounts
  alias Tracms.Audit

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:active_session_count, length(Accounts.list_user_sessions(user)))
     |> assign(:recent_activities, Audit.list_for_user(user))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="settings"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Profile"
          title={profile_name(@current_scope.user)}
          copy="Review your identity, access, security, and recent TRACMS activity."
        >
          <:actions>
            <.button navigate={~p"/users/settings"} variant="secondary">Edit Settings</.button>
          </:actions>
        </.portal_page_header>

        <div class="content-grid">
          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header eyebrow="Account" title="Profile Information" />

            <div class="mb-6 flex flex-wrap items-center gap-4 rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-[var(--tracms-surface-muted)] p-5">
              <span
                class="grid size-16 place-items-center rounded-full bg-[var(--tracms-primary)] text-xl font-bold text-white"
                role="img"
                aria-label="Profile initials"
              >
                {user_initials(@current_scope.user)}
              </span>
              <div class="min-w-0">
                <h2 class="text-xl font-extrabold tracking-tight">
                  {profile_name(@current_scope.user)}
                </h2>
                <p class="text-sm text-[var(--tracms-text-muted)]">
                  {profile_position(@current_scope.user)}
                </p>
              </div>
              <.badge tone={account_status_tone(@current_scope.user.status)} class="sm:ml-auto">
                {account_status_label(@current_scope.user.status)}
              </.badge>
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.profile_fact label="Full Name" value={profile_name(@current_scope.user)} />
              <.profile_fact label="Position" value={profile_position(@current_scope.user)} />
              <.profile_fact label="Employee ID" value={employee_number(@current_scope.user)} />
              <.profile_fact icon="hero-envelope" label="Email" value={@current_scope.user.email} />
              <.profile_fact
                icon="hero-building-office-2"
                label="Office"
                value={office_name(@current_scope.user)}
              />
              <.profile_fact
                icon="hero-folder"
                label="Division"
                value={division_name(@current_scope.user)}
              />
              <.profile_fact
                icon="hero-phone"
                label="Contact"
                value={contact_number(@current_scope.user)}
              />
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header eyebrow="Access" title="Access Information" />
            <dl class="space-y-4 text-sm">
              <div>
                <dt class="font-semibold text-[var(--tracms-text-muted)]">Role</dt>
                <dd class="mt-1 font-semibold">{role_name(@current_scope.user)}</dd>
              </div>
              <div>
                <dt class="font-semibold text-[var(--tracms-text-muted)]">Permission level</dt>
                <dd class="mt-1">{permission_level(@current_scope.role_key)}</dd>
              </div>
              <div>
                <dt class="font-semibold text-[var(--tracms-text-muted)]">Account created</dt>
                <dd class="mt-1">{format_account_created_date(@current_scope.user.inserted_at)}</dd>
              </div>
              <div>
                <dt class="font-semibold text-[var(--tracms-text-muted)]">Active sessions</dt>
                <dd class="mt-1">{@active_session_count} active sign-in(s)</dd>
              </div>
            </dl>

            <div class="mt-6 border-t border-[var(--tracms-border)] pt-5">
              <h3 class="font-semibold">Account security</h3>
              <p class="mt-1 text-sm leading-6 text-[var(--tracms-text-muted)]">
                Two-factor authentication is not configured for TRACMS yet. Password and email
                changes require a recent sign-in.
              </p>
              <.button navigate={~p"/users/settings"} variant="secondary" class="mt-4">
                Manage Account Security
              </.button>
            </div>
          </section>

          <section id="recent-activity" class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header eyebrow="Audit Information" title="Recent Activity" />
            <div :if={@recent_activities == []} class="portal-empty-quiet">
              No auditable actions have been recorded for this account yet.
            </div>
            <ol :if={@recent_activities != []} class="divide-y divide-[var(--tracms-border)]">
              <li :for={activity <- @recent_activities} class="py-4 first:pt-0 last:pb-0">
                <p class="font-semibold">{format_action(activity.action)}</p>
                <p class="mt-1 text-sm text-[var(--tracms-text-muted)]">
                  {activity_description(activity)}
                </p>
                <time class="mt-1 block text-xs text-[var(--tracms-text-muted)]">
                  {format_timestamp(activity.inserted_at)}
                </time>
              </li>
            </ol>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :icon, :string, default: nil
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp profile_fact(assigns) do
    ~H"""
    <div class="feature-card">
      <div class="feature-title">
        <.icon :if={@icon} name={@icon} class="mr-1 inline size-4" /> {@label}
      </div>
      <div class="feature-copy">{@value}</div>
    </div>
    """
  end

  defp profile_name(%{full_name: full_name}) when is_binary(full_name) and full_name != "",
    do: full_name

  defp profile_name(_user), do: "Administrator"

  defp profile_position(%{position: position}) when is_binary(position) and position != "",
    do: position

  defp profile_position(_user), do: "Position not assigned"

  defp employee_number(%{employee_number: employee_number})
       when is_binary(employee_number) and employee_number != "",
       do: employee_number

  defp employee_number(_user), do: "Not assigned"

  defp contact_number(%{contact_number: contact_number})
       when is_binary(contact_number) and contact_number != "",
       do: contact_number

  defp contact_number(_user), do: "Not provided"

  defp office_name(%{office: office}) when not is_nil(office), do: office.name
  defp office_name(_user), do: "Not assigned"

  defp division_name(%{office: %{division: division}}) when not is_nil(division),
    do: division.name

  defp division_name(_user), do: "Not assigned"

  defp role_name(%{role: %{name: name}}) when is_binary(name), do: name
  defp role_name(_user), do: "No role assigned"

  defp permission_level("regional_admin"), do: "Full regional system access"
  defp permission_level("division_admin"), do: "Division management access"
  defp permission_level("training_coordinator"), do: "Office training management access"
  defp permission_level(_role_key), do: "Standard account access"

  defp account_status_tone(:active), do: :success
  defp account_status_tone(:pending), do: :warning
  defp account_status_tone(:disabled), do: :danger

  defp account_status_label(:active), do: "Active"
  defp account_status_label(:pending), do: "Pending approval"
  defp account_status_label(:disabled), do: "Disabled"

  defp format_action(action) do
    action
    |> String.split("_")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp activity_description(%{training_activity: %{title: title}}) when is_binary(title),
    do: title

  defp activity_description(_activity), do: "TRACMS account activity"

  defp format_account_created_date(%DateTime{} = date), do: Calendar.strftime(date, "%b %d, %Y")
  defp format_account_created_date(_date), do: "Not available"

  defp format_timestamp(%DateTime{} = timestamp),
    do: Calendar.strftime(timestamp, "%b %d, %Y %I:%M %p UTC")

  defp format_timestamp(_timestamp), do: "Not available"

  defp user_initials(%{full_name: full_name, email: email}) do
    (full_name || email)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end
