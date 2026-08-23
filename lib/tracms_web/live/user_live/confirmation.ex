defmodule TracmsWeb.UserLive.Confirmation do
  use TracmsWeb, :live_view

  alias Tracms.Accounts

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
              Continue through the secure TRACMS email verification flow to complete access to the
              DepEd Region IX training portal.
            </p>
          </div>

          <div class="auth-portal-feature-list">
            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-shield-check" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Protected Access</p>
                <p class="auth-portal-feature-copy">
                  Verification links help secure authorized portal use.
                </p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-users" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Personnel Access</p>
                <p class="auth-portal-feature-copy">
                  Continue using your approved DepEd Region IX account.
                </p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-clipboard-document-check" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Portal Integrity</p>
                <p class="auth-portal-feature-copy">
                  Access actions are validated before entry to TRACMS.
                </p>
              </div>
            </div>

            <div class="auth-portal-feature-item">
              <div class="auth-portal-feature-icon">
                <.icon name="hero-academic-cap" class="size-7" />
              </div>
              <div>
                <p class="auth-portal-feature-title">Training Records</p>
                <p class="auth-portal-feature-copy">
                  Proceed to your assigned training workspace after verification.
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
            <p class="auth-portal-security-kicker">Verified Access</p>
            <p class="auth-portal-security-copy">
              Secure email verification for TRACMS portal access.
            </p>
          </div>

          <article class="auth-card auth-portal-card auth-portal-card-compact">
            <div class="auth-portal-avatar">
              <.icon
                name={if @user.confirmed_at, do: "hero-check-badge", else: "hero-envelope-open"}
                class="size-11"
              />
            </div>

            <div class="auth-card-header auth-portal-card-header">
              <p class="eyebrow">Email verification</p>
              <h2 class="auth-card-title">
                <%= if @user.confirmed_at do %>
                  Continue to TRACMS
                <% else %>
                  Confirm sign-in
                <% end %>
              </h2>
              <p class="auth-card-copy">{@user.email}</p>
            </div>

            <.form
              :if={!@user.confirmed_at}
              for={@form}
              id="confirmation_form"
              phx-mounted={JS.focus_first()}
              phx-submit="submit"
              action={~p"/users/log-in?_action=confirmed"}
              phx-trigger-action={@trigger_submit}
              class="auth-form auth-portal-form"
            >
              <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

              <div class="auth-form-section">
                <div class="auth-portal-confirmation-copy">
                  Confirm your secure login request to activate this TRACMS session.
                </div>
                <div class="auth-portal-form-meta">
                  <.input
                    :if={!@current_scope}
                    field={@form[:remember_me]}
                    type="checkbox"
                    label="Remember Me on This Device"
                    class="auth-portal-checkbox"
                  />
                </div>
              </div>

              <.button phx-disable-with="Confirming..." class="w-full auth-portal-submit">
                <.icon name="hero-check-circle" class="size-5" /> Confirm and Continue
              </.button>
            </.form>

            <.form
              :if={@user.confirmed_at}
              for={@form}
              id="login_form"
              phx-submit="submit"
              phx-mounted={JS.focus_first()}
              action={~p"/users/log-in"}
              phx-trigger-action={@trigger_submit}
              class="auth-form auth-portal-form"
            >
              <input type="hidden" name={@form[:token].name} value={@form[:token].value} />

              <div class="auth-form-section">
                <div class="auth-portal-confirmation-copy">
                  Your email verification is ready. Continue to your authorized TRACMS workspace.
                </div>
                <div class="auth-portal-form-meta">
                  <.input
                    :if={!@current_scope}
                    field={@form[:remember_me]}
                    type="checkbox"
                    label="Remember Me on This Device"
                    class="auth-portal-checkbox"
                  />
                </div>
              </div>

              <.button phx-disable-with="Continuing..." class="w-full auth-portal-submit">
                <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Continue
              </.button>
            </.form>
          </article>

          <article class="auth-portal-notice">
            <div class="auth-portal-notice-icon">
              <.icon name="hero-information-circle" class="size-6" />
            </div>
            <div>
              <p class="auth-portal-notice-title">Verification Notice</p>
              <p class="auth-portal-notice-copy">
                This verification link is intended only for the authorized recipient. Do not share
                portal access links with unauthorized users.
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
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token, "remember_me" => false}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
