defmodule TracmsWeb.UserLive.Login do
  use TracmsWeb, :live_view

  alias Tracms.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} variant="auth">
      <section class="auth-stage">
        <article class="auth-brand-panel">
          <div class="auth-brand-stack">
            <p class="hero-kicker">DepEd Region IX</p>
            <h1 class="auth-brand-title">
              Training records, registration, and certification in one system.
            </h1>
            <p class="auth-brand-copy">
              Internal access for the regional training management platform.
            </p>
          </div>
          <div class="auth-brand-tag">Secure regional access</div>
        </article>

        <article class="auth-card">
          <div class="auth-card-header">
            <p class="eyebrow">Secure access</p>
            <h2 class="auth-card-title">
              <%= if @current_scope do %>
                Re-authenticate
              <% else %>
                Sign in to TRACMS
              <% end %>
            </h2>
            <p class="auth-card-copy">
              <%= if @current_scope do %>
                Confirm your identity to continue.
              <% else %>
                Sign in with your registered account.
              <% end %>
            </p>
          </div>

          <div :if={local_mail_adapter?()} class="auth-note">
            <.icon
              name="hero-information-circle"
              class="size-5 shrink-0 text-[var(--tracms-primary)]"
            />
            <div>
              <p class="font-semibold">Local mail adapter is active.</p>
              <p>
                Sign-in links are delivered to <.link href="/dev/mailbox" class="auth-inline-link">the development mailbox</.link>.
              </p>
            </div>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="auth-form"
          >
            <div class="auth-form-section">
              <div>
                <p class="auth-form-heading">Password sign-in</p>
                <p class="auth-form-copy">Use your email and password.</p>
              </div>

              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                required
                phx-mounted={JS.focus()}
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                spellcheck="false"
                required
              />
              <.input
                field={f[:remember_me]}
                type="checkbox"
                label="Keep me signed in on this device"
              />
            </div>

            <.button class="w-full">Sign in</.button>
          </.form>

          <div class="auth-divider">
            <span>Email-link access</span>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/users/log-in"}
            phx-submit="submit_magic"
            class="auth-form"
          >
            <div class="auth-form-section">
              <div>
                <p class="auth-form-heading">Send secure sign-in link</p>
                <p class="auth-form-copy">Use email-link access instead.</p>
              </div>

              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                required
              />
            </div>

            <.button variant="secondary" class="w-full">Send secure sign-in link</.button>
          </.form>

          <p :if={!@current_scope} class="auth-footer-copy">
            Need an account?
            <.link navigate={~p"/users/register"} class="auth-inline-link">
              Create account
            </.link>
          </p>
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

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:tracms, Tracms.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
