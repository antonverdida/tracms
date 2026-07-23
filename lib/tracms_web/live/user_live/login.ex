defmodule TracmsWeb.UserLive.Login do
  use TracmsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} variant="auth">
      <section class="auth-stage auth-portal-stage">
        <article class="auth-brand-panel auth-portal-brand-panel">
          <div class="auth-portal-brand-top">
            <img src={~p"/images/tracms-logo.svg"} alt="TRACMS logo" class="auth-portal-brand-logo" />
            <div class="auth-portal-brand-lockup">
              <p class="auth-portal-brand-overline">Department of Education</p>
              <p class="auth-portal-brand-region">Region IX</p>
            </div>
          </div>

          <div class="auth-brand-stack">
            <p class="auth-portal-brand-divider"></p>
            <h1 class="auth-portal-brand-system">TRACMS</h1>
            <h2 class="auth-portal-brand-title">
              Training, Registration, Attendance, and Certification Management System
            </h2>
            <p class="auth-brand-copy">
              A centralized platform for managing training activities, participant
              registration, attendance monitoring, digital certification, and professional
              development records for DepEd Region IX.
            </p>
          </div>

          <div class="auth-portal-feature-list">
            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-book-open" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Training Management</p>
                <p class="auth-portal-feature-copy">
                  Create, manage, and monitor training activities.
                </p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-users" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Participant Registration</p>
                <p class="auth-portal-feature-copy">
                  Online registration and participant management.
                </p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-clipboard-document-check" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Attendance Tracking</p>
                <p class="auth-portal-feature-copy">Manual and QR-based attendance monitoring.</p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-academic-cap" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Digital Certificates</p>
                <p class="auth-portal-feature-copy">
                  Automated certificate generation and distribution.
                </p>
              </div>
            </div>
          </div>

          <div class="auth-portal-brand-surface" aria-hidden="true"></div>
        </article>

        <article class="auth-portal-pane">
          <div class="auth-portal-security-head">
            <div class="auth-portal-security-icon">
              <.icon name="hero-shield-check" class="size-10" />
            </div>
            <p class="auth-portal-security-kicker">Secure Access</p>
            <p class="auth-portal-security-copy">Authorized DepEd Region IX personnel only.</p>
          </div>

          <article class="auth-card auth-portal-card">
            <div class="auth-portal-avatar">
              <.icon name="hero-user-circle" class="size-11" />
            </div>

            <div class="auth-card-header auth-portal-card-header">
              <h2 class="auth-card-title">
                <%= if @current_scope do %>
                  Secure Login
                <% else %>
                  Welcome Back!
                <% end %>
              </h2>
              <p class="auth-card-copy">
                <%= if @current_scope do %>
                  Confirm your password to continue to your TRACMS workspace.
                <% else %>
                  Sign in to access your TRACMS account.
                <% end %>
              </p>
            </div>

            <.form
              :let={f}
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
              class="auth-form auth-portal-form"
            >
              <div class="auth-form-section">
                <label class="auth-portal-field-block">
                  <span class="field-label auth-portal-label">Email Address</span>
                  <div class="auth-portal-input-shell">
                    <.icon name="hero-envelope" class="auth-portal-input-icon" />
                    <input
                      readonly={!!@current_scope}
                      type="email"
                      name={f[:email].name}
                      id={f[:email].id}
                      value={f[:email].value}
                      class="auth-portal-input"
                      autocomplete="username"
                      spellcheck="false"
                      placeholder="Enter your DepEd email address"
                      required
                      phx-mounted={JS.focus()}
                    />
                  </div>
                </label>

                <label class="auth-portal-field-block">
                  <span class="field-label auth-portal-label">Password</span>
                  <div class="auth-portal-input-shell">
                    <.icon name="hero-lock-closed" class="auth-portal-input-icon" />
                    <input
                      type="password"
                      name={f[:password].name}
                      id={f[:password].id}
                      value={f[:password].value}
                      class="auth-portal-input auth-portal-input-password"
                      autocomplete="current-password"
                      spellcheck="false"
                      placeholder="Enter your password"
                      required
                    />
                    <.icon name="hero-eye" class="auth-portal-input-icon auth-portal-input-icon-end" />
                  </div>
                </label>

                <div class="auth-portal-form-meta">
                  <.input
                    field={f[:remember_me]}
                    type="checkbox"
                    label="Remember me on this device"
                    class="auth-portal-checkbox"
                  />
                </div>
              </div>

              <.button class="w-full auth-portal-submit">
                <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Sign In
              </.button>

              <p class="auth-portal-support-copy">
                Forgot your password? Contact your system administrator for password assistance.
              </p>
            </.form>
          </article>

          <article class="auth-portal-notice">
            <div class="auth-portal-notice-icon">
              <.icon name="hero-shield-check" class="size-6" />
            </div>
            <div>
              <p class="auth-portal-notice-title">Security Notice</p>
              <p class="auth-portal-notice-copy">
                Unauthorized access is prohibited and may be subject to applicable government
                policies and regulations.
              </p>
            </div>
          </article>

          <footer class="auth-portal-footer">
            <p>&copy; 2026 Department of Education - Region IX</p>
            <p>All rights reserved.</p>
          </footer>
        </article>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email, "remember_me" => false}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end
end
