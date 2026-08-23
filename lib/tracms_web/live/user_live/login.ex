defmodule TracmsWeb.UserLive.Login do
  use TracmsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} variant="auth">
      <section class="auth-stage auth-portal-stage auth-portal-login-stage">
        <article class="auth-portal-pane">
          <article class="auth-card auth-portal-card auth-portal-login-card">
            <div class="auth-portal-avatar">
              <img
                src={~p"/images/tracms-region-ix-logo.png"}
                alt="TRACMS Region IX logo"
                class="auth-portal-card-logo"
              />
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
                    label="Remember Me on This Device"
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
