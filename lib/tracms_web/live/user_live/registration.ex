defmodule TracmsWeb.UserLive.Registration do
  use TracmsWeb, :live_view

  alias Tracms.Accounts
  alias Tracms.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} variant="auth">
      <section class="auth-stage auth-portal-stage">
        <article class="auth-brand-panel auth-portal-brand-panel">
          <div class="auth-portal-brand-top">
            <img
              src={~p"/images/tracms-region-ix-logo.png"}
              alt="TRACMS Region IX logo"
              class="auth-portal-brand-logo"
            />
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
              <.icon name="hero-identification" class="size-10" />
            </div>
            <p class="auth-portal-security-kicker">Portal Access</p>
            <p class="auth-portal-security-copy">Request secure access to the TRACMS platform.</p>
          </div>

          <article class="auth-card auth-portal-card auth-portal-card-compact">
            <div class="auth-portal-avatar">
              <.icon name="hero-user-plus" class="size-11" />
            </div>

            <div class="auth-card-header auth-portal-card-header">
              <h2 class="auth-card-title">Create account</h2>
              <p class="auth-card-copy">
                Choose a username and provide your work email to receive your first secure sign-in link.
              </p>
            </div>

            <.form
              for={@form}
              id="registration_form"
              phx-submit="save"
              phx-change="validate"
              class="auth-form auth-portal-form"
            >
              <div class="auth-form-section">
                <label class="auth-portal-field-block">
                  <span class="field-label auth-portal-label">Username</span>
                  <div class="auth-portal-input-shell">
                    <.icon name="hero-user" class="auth-portal-input-icon" />
                    <input
                      type="text"
                      name={@form[:username].name}
                      id={@form[:username].id}
                      value={@form[:username].value}
                      class="auth-portal-input"
                      autocomplete="username"
                      spellcheck="false"
                      placeholder="Choose a username"
                      required
                      phx-mounted={JS.focus()}
                    />
                  </div>
                </label>
                <p
                  :for={msg <- @form[:username].errors}
                  class="mt-1 flex items-center gap-2 text-sm text-[var(--tracms-danger)]"
                >
                  <.icon name="hero-exclamation-circle" class="size-5" />
                  {translate_error(msg)}
                </p>

                <label class="auth-portal-field-block">
                  <span class="field-label auth-portal-label">Email Address</span>
                  <div class="auth-portal-input-shell">
                    <.icon name="hero-envelope" class="auth-portal-input-icon" />
                    <input
                      type="email"
                      name={@form[:email].name}
                      id={@form[:email].id}
                      value={@form[:email].value}
                      class="auth-portal-input"
                      autocomplete="username"
                      spellcheck="false"
                      placeholder="Enter your DepEd email address"
                      required
                    />
                  </div>
                </label>
                <p
                  :for={msg <- @form[:email].errors}
                  class="mt-1 flex items-center gap-2 text-sm text-[var(--tracms-danger)]"
                >
                  <.icon name="hero-exclamation-circle" class="size-5" />
                  {translate_error(msg)}
                </p>
              </div>

              <.button phx-disable-with="Creating Account..." class="w-full auth-portal-submit">
                <.icon name="hero-paper-airplane" class="size-5" /> Create Account
              </.button>
            </.form>

            <p class="auth-portal-support-copy">
              Already registered?
              <.link navigate={~p"/users/log-in"} class="auth-inline-link">
                Sign in
              </.link>
            </p>
          </article>

          <article class="auth-portal-notice">
            <div class="auth-portal-notice-icon">
              <.icon name="hero-information-circle" class="size-6" />
            </div>
            <div>
              <p class="auth-portal-notice-title">Access Guidance</p>
              <p class="auth-portal-notice-copy">
                Use your official work email address. Access approval and portal use remain
                subject to applicable internal DepEd Region IX policies.
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
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: TracmsWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "We sent a confirmation link to #{user.email}. Open it to activate your TRACMS account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
