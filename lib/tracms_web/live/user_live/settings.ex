defmodule TracmsWeb.UserLive.Settings do
  use TracmsWeb, :live_view

  on_mount {TracmsWeb.UserAuth, :require_sudo_mode}

  alias Tracms.Accounts
  alias Tracms.Accounts.{Scope, User}

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
          eyebrow="Settings"
          title="Account Settings"
          copy="Manage your profile, account security, and role visibility in TRACMS."
        >
          <:actions>
            <.button navigate={~p"/dashboard"} variant="ghost">Back to dashboard</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@settings_summary_cards} />

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Profile readiness"
            title="Account Completeness"
            meta="Complete profile details help improve training records, approvals, and certificate outputs."
          />

          <div class="portal-workflow-list">
            <div
              :for={item <- profile_readiness_items(@current_scope.user)}
              class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
            >
              <div>
                <p class="portal-workflow-label">{item.label}</p>
                <p class="portal-workflow-copy">{item.description}</p>
              </div>
              <span class="portal-workflow-value">{item.value}</span>
            </div>
          </div>
        </section>

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Session history"
            title="Active Sessions"
            meta="Current valid TRACMS sign-in sessions recorded for your account."
          />

          <%= if @session_history == [] do %>
            <div class="portal-empty-quiet">
              <p class="section-copy">
                No active session history is currently available for this account.
              </p>
            </div>
          <% else %>
            <div class="portal-activity-list">
              <div :for={item <- @session_history} class="portal-activity-item">
                <div class={["portal-activity-icon", "portal-activity-icon-#{item.tone}"]}>
                  <.icon name={item.icon} class="size-5" />
                </div>

                <div class="portal-activity-copy">
                  <h3 class="portal-activity-title">{item.title}</h3>
                  <p class="portal-activity-meta">{item.detail}</p>
                </div>

                <span class="portal-activity-time">{item.timestamp}</span>
              </div>
            </div>
          <% end %>
        </section>

        <div class="content-grid">
          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Profile information"
              title="Profile"
              meta="Update the personal account details shown across your training records."
            />

            <.form
              for={@profile_form}
              id="profile_form"
              phx-submit="update_profile"
              phx-change="validate_profile"
            >
              <div class="grid gap-4 md:grid-cols-2">
                <.input
                  field={@profile_form[:full_name]}
                  type="text"
                  label="Full name"
                  autocomplete="name"
                  placeholder="Juan Dela Cruz"
                />
                <.input
                  field={@profile_form[:employee_number]}
                  type="text"
                  label="Employee ID"
                  placeholder="DEPED-2026-00125"
                />
              </div>

              <div class="mt-6 grid gap-4 md:grid-cols-2">
                <div class="feature-card">
                  <div class="feature-title">Office</div>
                  <div class="feature-copy">{office_name(@current_scope.user)}</div>
                </div>
                <div class="feature-card">
                  <div class="feature-title">Division</div>
                  <div class="feature-copy">{division_name(@current_scope.user)}</div>
                </div>
              </div>

              <div class="mt-6 flex justify-end">
                <.button variant="primary" phx-disable-with="Saving...">Save profile</.button>
              </div>
            </.form>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Role and access"
              title="Access Summary"
              meta="Read-only assignment and permissions information."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Account role</div>
                <div class="feature-copy">{role_name(@current_scope.user)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Account status</div>
                <div class="feature-copy">{account_status(@current_scope.user.status)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Office assignment</div>
                <div class="feature-copy">{office_name(@current_scope.user)}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Division assignment</div>
                <div class="feature-copy">{division_name(@current_scope.user)}</div>
              </div>
            </div>

            <div class="mt-6">
              <h3 class="section-title">Permissions</h3>
              <div class="mt-4 portal-workflow-list">
                <div
                  :for={permission <- permissions_summary(@current_scope)}
                  class="portal-workflow-item portal-workflow-item-slate"
                >
                  <div>
                    <p class="portal-workflow-label">{permission}</p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Account security"
              title="Email and password"
              meta="Sensitive changes require your current authenticated session."
            />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Current email</div>
                <div class="feature-copy">{@current_email}</div>
              </div>
              <div class="feature-card">
                <div class="feature-title">Authenticated access</div>
                <div class="feature-copy">{authenticated_label(@current_scope.user)}</div>
              </div>
            </div>

            <div class="mt-6 rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white/70 p-5">
              <h3 class="section-title">Change email</h3>
              <p class="section-copy mt-2">
                Update the email address used to sign in to TRACMS. A confirmation link will be sent to the new address.
              </p>

              <.form
                for={@email_form}
                id="email_form"
                phx-submit="update_email"
                phx-change="validate_email"
                class="mt-5"
              >
                <.input
                  field={@email_form[:email]}
                  type="email"
                  label="New email address"
                  autocomplete="username"
                  spellcheck="false"
                  required
                />
                <div class="mt-4 flex justify-end">
                  <.button variant="primary" phx-disable-with="Changing...">Change email</.button>
                </div>
              </.form>
            </div>

            <div class="mt-6 rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white/70 p-5">
              <h3 class="section-title">Update password</h3>
              <p class="section-copy mt-2">
                Use a strong password to protect your TRACMS account and authorized records access.
              </p>

              <.form
                for={@password_form}
                id="password_form"
                action={~p"/users/update-password"}
                method="post"
                phx-change="validate_password"
                phx-submit="update_password"
                phx-trigger-action={@trigger_submit}
                class="mt-5"
              >
                <input
                  name={@password_form[:email].name}
                  type="hidden"
                  id="hidden_user_email"
                  spellcheck="false"
                  value={@current_email}
                />
                <div class="grid gap-4 md:grid-cols-2">
                  <.input
                    field={@password_form[:password]}
                    type="password"
                    label="New password"
                    autocomplete="new-password"
                    spellcheck="false"
                    required
                  />
                  <.input
                    field={@password_form[:password_confirmation]}
                    type="password"
                    label="Confirm new password"
                    autocomplete="new-password"
                    spellcheck="false"
                  />
                </div>
                <div class="mt-4 flex justify-end">
                  <.button variant="primary" phx-disable-with="Saving...">
                    Update password
                  </.button>
                </div>
              </.form>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Notification summary"
              title="Communication"
              meta="Configure the operational updates and announcements saved for your account."
            />

            <div class="portal-workflow-list">
              <div
                :for={item <- notification_summary(@current_scope)}
                class={["portal-workflow-item", "portal-workflow-item-#{item.tone}"]}
              >
                <div>
                  <p class="portal-workflow-label">{item.label}</p>
                  <p class="portal-workflow-copy">{item.description}</p>
                </div>
                <span class="portal-workflow-value">{item.value}</span>
              </div>
            </div>

            <div class="mt-6 rounded-[var(--tracms-radius-md)] border border-[var(--tracms-border)] bg-white/70 p-5">
              <h3 class="section-title">Saved notification preferences</h3>
              <p class="section-copy mt-2">
                Choose which TRACMS account and training updates should remain enabled for your user record.
              </p>

              <.form
                for={@notification_preferences_form}
                id="notification_preferences_form"
                phx-submit="update_notification_preferences"
                phx-change="validate_notification_preferences"
                class="mt-5"
              >
                <div class="grid gap-4 md:grid-cols-2">
                  <.input
                    field={@notification_preferences_form[:training_announcements]}
                    type="checkbox"
                    label="Training announcements"
                  />
                  <.input
                    field={@notification_preferences_form[:registration_updates]}
                    type="checkbox"
                    label="Registration updates"
                  />
                  <.input
                    field={@notification_preferences_form[:certificate_availability]}
                    type="checkbox"
                    label="Certificate availability"
                  />
                  <.input
                    field={@notification_preferences_form[:system_announcements]}
                    type="checkbox"
                    label="System announcements"
                  />
                </div>

                <div class="mt-4 flex justify-end">
                  <.button variant="primary" phx-disable-with="Saving...">
                    Save preferences
                  </.button>
                </div>
              </.form>
            </div>
          </section>

          <section class="panel portal-list-panel">
            <.portal_panel_header
              eyebrow="Recent account activity"
              title="Activity"
              meta="Important account milestones currently available from TRACMS."
            />

            <%= if account_activity(@current_scope.user) == [] do %>
              <div class="portal-empty-quiet">
                <p class="section-copy">
                  Account activity details will appear here as more audit and security events are added to TRACMS.
                </p>
              </div>
            <% else %>
              <div class="portal-activity-list">
                <div :for={item <- account_activity(@current_scope.user)} class="portal-activity-item">
                  <div class={["portal-activity-icon", "portal-activity-icon-#{item.tone}"]}>
                    <.icon name={item.icon} class="size-5" />
                  </div>

                  <div class="portal-activity-copy">
                    <h3 class="portal-activity-title">{item.title}</h3>
                    <p class="portal-activity-meta">{item.detail}</p>
                  </div>

                  <span class="portal-activity-time">{item.timestamp}</span>
                </div>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> load_user_settings(user)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("validate_profile", %{"user" => user_params}, socket) do
    profile_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_profile(profile_attrs(user_params))
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, profile_form: profile_form)}
  end

  def handle_event(
        "validate_notification_preferences",
        %{"notification_preferences" => notification_preferences},
        socket
      ) do
    {:noreply,
     assign(
       socket,
       :notification_preferences_form,
       to_form(
         User.default_notification_preferences(notification_preferences),
         as: :notification_preferences
       )
     )}
  end

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_profile(user, profile_attrs(user_params)) do
      {:ok, updated_user} ->
        updated_user =
          %{updated_user | authenticated_at: socket.assigns.current_scope.user.authenticated_at}

        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> load_user_settings(updated_user)
         |> put_flash(:info, "Profile updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event(
        "update_notification_preferences",
        %{"notification_preferences" => notification_preferences},
        socket
      ) do
    user = socket.assigns.current_scope.user

    case Accounts.update_user_notification_preferences(user, %{
           "notification_preferences" => notification_preferences
         }) do
      {:ok, updated_user} ->
        updated_user =
          %{updated_user | authenticated_at: socket.assigns.current_scope.user.authenticated_at}

        {:noreply,
         socket
         |> assign(:current_scope, Scope.for_user(updated_user))
         |> load_user_settings(updated_user)
         |> put_flash(:info, "Notification preferences updated successfully.")}

      {:error, changeset} ->
        {:noreply,
         assign(
           socket,
           :notification_preferences_form,
           to_form(
             User.default_notification_preferences(changeset.changes.notification_preferences),
             as: :notification_preferences
           )
         )}
    end
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  defp profile_attrs(user_params) do
    Map.take(user_params, ["full_name", "employee_number"])
  end

  defp role_name(%{role: role}) when not is_nil(role), do: role.name
  defp role_name(_user), do: "Authorized User"

  defp account_status(status) when is_atom(status) do
    status
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp account_status(_status), do: "Active"

  defp office_name(%{office: office}) when not is_nil(office), do: office.name
  defp office_name(_user), do: "Not assigned"

  defp division_name(%{office: %{division: division}}) when not is_nil(division),
    do: division.name

  defp division_name(_user), do: "Not assigned"

  defp authenticated_label(%{authenticated_at: %DateTime{} = authenticated_at}) do
    "Verified #{format_datetime(authenticated_at)}"
  end

  defp authenticated_label(_user), do: "Authenticated session required"

  defp permissions_summary(%Scope{role_key: "regional_admin"}) do
    [
      "Manage trainings across the region",
      "Approve registrations and operational records",
      "Review reports and completion workflows",
      "Issue and monitor certificates"
    ]
  end

  defp permissions_summary(%Scope{role_key: "division_admin"}) do
    [
      "Review division-scoped training operations",
      "Approve registrations within the assigned division",
      "Monitor attendance, completion, and reports",
      "Access certificate issuance for managed trainings"
    ]
  end

  defp permissions_summary(%Scope{role_key: "training_coordinator"}) do
    [
      "Manage office training activities",
      "Monitor attendance and completion records",
      "Review participant registrations",
      "Issue certificates within the assigned scope"
    ]
  end

  defp permissions_summary(_scope) do
    [
      "Browse published trainings",
      "Submit and track registrations",
      "Complete evaluation requirements",
      "Access issued certificates"
    ]
  end

  defp notification_summary(%Scope{} = scope) do
    [
      %{
        label: "Account security notices",
        description: "Email confirmation and credential-related account updates.",
        value: "Enabled",
        tone: "blue"
      },
      %{
        label: "Training workflow updates",
        description: training_notification_copy(scope),
        value: preference_label(scope.user, "training_announcements"),
        tone: preference_tone(scope.user, "training_announcements")
      },
      %{
        label: "Certificate availability",
        description: "Issued certificate records and participant-facing release notices.",
        value: preference_label(scope.user, "certificate_availability"),
        tone: preference_tone(scope.user, "certificate_availability")
      },
      %{
        label: "Registration updates",
        description: "Approval, waitlist, and registration status notifications.",
        value: preference_label(scope.user, "registration_updates"),
        tone: preference_tone(scope.user, "registration_updates")
      }
    ]
  end

  defp account_activity(user) do
    [
      user.authenticated_at &&
        %{
          sort_at: user.authenticated_at,
          icon: "hero-shield-check",
          tone: "green",
          title: "Authenticated session verified",
          detail: "Your current secure session passed the required re-authentication check.",
          timestamp: format_datetime(user.authenticated_at)
        },
      user.confirmed_at &&
        %{
          sort_at: user.confirmed_at,
          icon: "hero-envelope",
          tone: "blue",
          title: "Email confirmed",
          detail: "Your sign-in email address has been verified for TRACMS access.",
          timestamp: format_datetime(user.confirmed_at)
        },
      user.approved_at &&
        %{
          sort_at: user.approved_at,
          icon: "hero-check-badge",
          tone: "amber",
          title: "Account approved",
          detail: "Your account was activated for authorized TRACMS operations.",
          timestamp: format_datetime(user.approved_at)
        },
      user.inserted_at &&
        %{
          sort_at: user.inserted_at,
          icon: "hero-identification",
          tone: "slate",
          title: "Account created",
          detail: "Your TRACMS user record was created and registered in the system.",
          timestamp: format_datetime(user.inserted_at)
        }
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(&DateTime.to_unix(&1.sort_at, :second), :desc)
  end

  defp training_notification_copy(scope) do
    if Scope.training_manager?(scope) do
      "Operational alerts for trainings, registrations, attendance, and completion review."
    else
      "Registration, evaluation, and training participation updates for your assigned records."
    end
  end

  defp preference_label(user, key) do
    if User.default_notification_preferences(user.notification_preferences)[key] do
      "Enabled"
    else
      "Disabled"
    end
  end

  defp preference_tone(user, key) do
    if User.default_notification_preferences(user.notification_preferences)[key] do
      "green"
    else
      "slate"
    end
  end

  defp settings_summary_cards(%Scope{user: user} = scope, session_count) do
    [
      summary_card(
        "Profile completion",
        "#{profile_completion_count(user)}/4",
        "Full name, employee ID, role, and office context"
      ),
      summary_card(
        "Account status",
        account_status(user.status),
        "Current access standing in TRACMS"
      ),
      summary_card(
        "Security session",
        if(Accounts.sudo_mode?(user), do: "Verified", else: "Review required"),
        "Sensitive account actions require recent authentication"
      ),
      summary_card(
        "Active sessions",
        session_count,
        "Current valid session records for this account"
      ),
      summary_card(
        "Role scope",
        role_scope_label(scope),
        "Current authorization level for portal operations"
      )
    ]
  end

  defp profile_readiness_items(user) do
    [
      readiness_item(
        "Full name",
        present?(user.full_name),
        "Used in records, dashboards, and certificate outputs."
      ),
      readiness_item(
        "Employee ID",
        present?(user.employee_number),
        "Supports official training and personnel identification."
      ),
      readiness_item(
        "Office assignment",
        not is_nil(user.office),
        "Determines operational scope and organizational context."
      ),
      readiness_item(
        "Role assignment",
        not is_nil(user.role),
        "Controls the features and actions available in TRACMS."
      )
    ]
  end

  defp readiness_item(label, true, description) do
    %{label: label, value: "Complete", description: description, tone: "green"}
  end

  defp readiness_item(label, false, description) do
    %{label: label, value: "Pending", description: description, tone: "amber"}
  end

  defp profile_completion_count(user) do
    Enum.count([
      present?(user.full_name),
      present?(user.employee_number),
      not is_nil(user.role),
      not is_nil(user.office)
    ])
  end

  defp role_scope_label(%Scope{role_key: "regional_admin"}), do: "Region"
  defp role_scope_label(%Scope{role_key: "division_admin"}), do: "Division"
  defp role_scope_label(%Scope{role_key: "training_coordinator"}), do: "Office"
  defp role_scope_label(%Scope{role_key: "participant"}), do: "Participant"
  defp role_scope_label(_scope), do: "Assigned"

  defp present?(value), do: value not in [nil, ""]

  defp load_user_settings(socket, user) do
    session_history = session_history_items(user)
    current_scope = Scope.for_user(user)

    socket
    |> assign(:current_email, user.email)
    |> assign(:profile_form, to_form(Accounts.change_user_profile(user)))
    |> assign(
      :notification_preferences_form,
      to_form(User.default_notification_preferences(user.notification_preferences),
        as: :notification_preferences
      )
    )
    |> assign(:session_history, session_history)
    |> assign(
      :settings_summary_cards,
      settings_summary_cards(current_scope, length(session_history))
    )
  end

  defp session_history_items(user) do
    current_authenticated_at = user.authenticated_at

    user
    |> Accounts.list_user_sessions()
    |> Enum.map(fn session ->
      current_session? =
        current_authenticated_at &&
          session.authenticated_at &&
          DateTime.compare(session.authenticated_at, current_authenticated_at) == :eq

      %{
        icon: if(current_session?, do: "hero-shield-check", else: "hero-device-phone-mobile"),
        tone: if(current_session?, do: "green", else: "blue"),
        title: if(current_session?, do: "Current verified session", else: "Active session"),
        detail:
          "Authenticated #{format_datetime(session.authenticated_at)} • issued #{format_datetime(session.inserted_at)}",
        timestamp: format_datetime(session.inserted_at)
      }
    end)
  end
end
