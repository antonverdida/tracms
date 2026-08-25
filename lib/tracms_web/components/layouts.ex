defmodule TracmsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TracmsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :variant, :string, default: "default", values: ~w(default auth dashboard)
  attr :active_nav, :string, default: nil

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class={[
      "app-shell",
      @variant == "auth" && "app-shell-auth",
      @variant == "dashboard" && "app-shell-dashboard"
    ]}>
      <.site_header current_scope={@current_scope} variant={@variant} active_nav={@active_nav} />

      <main class={[
        @variant == "default" && "page-wrap",
        @variant == "auth" && "auth-page-wrap",
        @variant == "dashboard" && "dashboard-page-wrap"
      ]}>
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :current_scope, :map, required: true
  attr :variant, :string, required: true
  attr :active_nav, :string, default: nil

  defp site_header(assigns) do
    ~H"""
    <header
      :if={@variant == "default"}
      class={["app-header", @variant == "auth" && "app-header-auth"]}
    >
      <div class="topbar">
        <div class="brand-lockup brand-lockup-static">
          <div class="brand-pill">
            <img
              src={~p"/images/tracms-region-ix-logo.png"}
              alt="TRACMS Region IX logo"
              class="brand-logo"
            />
          </div>

          <span class="brand-copy">
            <span class="eyebrow">DepEd Region IX</span>
            <span class="brand-title">TRACMS</span>
          </span>
        </div>

        <div class="header-utility">
          <nav class="nav-links" aria-label="Primary">
            <%= if @current_scope && @current_scope.user do %>
              <.link navigate={~p"/dashboard"} class={nav_link_class(@active_nav, "dashboard")}>
                Dashboard
              </.link>
              <.link navigate={~p"/trainings"} class={nav_link_class(@active_nav, "trainings")}>
                Training Management
              </.link>
              <.link
                navigate={~p"/registrations"}
                class={nav_link_class(@active_nav, "registrations")}
              >
                Registrations
              </.link>
              <.link navigate={~p"/attendance"} class={nav_link_class(@active_nav, "attendance")}>
                Attendance
              </.link>
              <.link navigate={~p"/certificates"} class={nav_link_class(@active_nav, "certificates")}>
                Certificates
              </.link>
              <.link navigate={~p"/users/settings"} class={nav_link_class(@active_nav, "settings")}>
                Settings
              </.link>
            <% else %>
              <.link navigate={~p"/"} class="nav-link">Home</.link>
              <.button :if={@variant != "auth"} navigate={~p"/users/log-in"} variant="secondary">
                Log In
              </.button>
            <% end %>
          </nav>

          <%= if @current_scope && @current_scope.user do %>
            <.account_menu current_scope={@current_scope} variant="default" />
          <% end %>
        </div>
      </div>
    </header>

    <header :if={@variant == "dashboard"} class="dashboard-header">
      <div class="dashboard-topbar-shell">
        <div class="dashboard-topbar">
          <div class="dashboard-brand-block">
            <div class="brand-pill dashboard-brand-pill">
              <img
                src={~p"/images/tracms-region-ix-logo.png"}
                alt="TRACMS Region IX logo"
                class="brand-logo"
              />
            </div>
            <span class="dashboard-brand-copy">
              <span class="dashboard-brand-eyebrow">Department of Education • Region IX</span>
              <span class="dashboard-brand-title">TRACMS Portal</span>
            </span>
          </div>

          <div class="dashboard-topbar-actions">
            <.account_menu current_scope={@current_scope} variant="dashboard" />
          </div>
        </div>
      </div>

      <div class="dashboard-nav-shell">
        <nav class="dashboard-menu" aria-label="Dashboard navigation">
          <.link
            navigate={~p"/dashboard"}
            class={dashboard_menu_link_class(@active_nav, "dashboard")}
          >
            Dashboard
          </.link>
          <.link navigate={~p"/trainings"} class={dashboard_menu_link_class(@active_nav, "trainings")}>
            Training Management
          </.link>
          <.link
            navigate={~p"/registrations"}
            class={dashboard_menu_link_class(@active_nav, "registrations")}
          >
            Registrations
          </.link>
          <.link
            navigate={~p"/attendance"}
            class={dashboard_menu_link_class(@active_nav, "attendance")}
          >
            Attendance
          </.link>
          <.link
            navigate={~p"/certificates"}
            class={dashboard_menu_link_class(@active_nav, "certificates")}
          >
            Certificates
          </.link>
          <.link
            navigate={~p"/users/settings"}
            class={dashboard_menu_link_class(@active_nav, "settings")}
          >
            Settings
          </.link>
        </nav>
      </div>
    </header>
    """
  end

  defp nav_link_class(active_nav, nav) do
    [
      "nav-link",
      active_nav == nav && "nav-link-active"
    ]
  end

  defp dashboard_menu_link_class(active_nav, nav) do
    [
      "dashboard-menu-link",
      active_nav == nav && "dashboard-menu-link-active"
    ]
  end

  attr :current_scope, :map, required: true
  attr :variant, :string, required: true, values: ~w(default dashboard)

  defp account_menu(assigns) do
    ~H"""
    <details id={"account-menu-#{@variant}"} class={"account-menu account-menu-#{@variant}"}>
      <summary class="account-menu-trigger">
        <span class="account-menu-avatar">{user_initials(@current_scope.user)}</span>
        <span class="account-menu-trigger-copy">
          <span class="account-menu-trigger-name">{user_display_name(@current_scope.user)}</span>
          <span class="account-menu-trigger-role">{account_role_label(@current_scope)}</span>
        </span>
        <.icon name="hero-chevron-down" class="account-menu-chevron size-4" />
      </summary>

      <div class="account-menu-popover">
        <div class="account-menu-identity">
          <span class="account-menu-avatar account-menu-avatar-large">
            {user_initials(@current_scope.user)}
          </span>
          <div class="account-menu-identity-copy">
            <p class="account-menu-name">{user_display_name(@current_scope.user)}</p>
            <p class="account-menu-username">@{@current_scope.user.username}</p>
            <p class="account-menu-role">{account_role_label(@current_scope)}</p>
          </div>
        </div>

        <nav class="account-menu-actions" aria-label="Account menu">
          <.link navigate={~p"/profile"} class="account-menu-action">
            <.icon name="hero-user-circle" class="size-5" /> View Profile
          </.link>
          <.link navigate={~p"/users/settings"} class="account-menu-action">
            <.icon name="hero-shield-check" class="size-5" /> Account &amp; Security
          </.link>
        </nav>

        <div class="account-menu-logout-wrap">
          <.button
            href={~p"/users/log-out"}
            method="delete"
            variant="ghost"
            class="account-menu-logout"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Log Out
          </.button>
        </div>
      </div>
    </details>
    """
  end

  defp user_display_name(%{full_name: full_name, email: email}) do
    full_name || email
  end

  defp user_initials(%{full_name: full_name, email: email}) do
    (full_name || email)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  defp account_role_label(%{role_key: "regional_admin"}), do: "Regional Administrator"
  defp account_role_label(%{role_key: "division_admin"}), do: "Division Administrator"
  defp account_role_label(%{role_key: "training_coordinator"}), do: "Training Coordinator"
  defp account_role_label(_scope), do: "Administrator"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
