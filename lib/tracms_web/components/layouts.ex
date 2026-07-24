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
        <.link navigate={~p"/"} class="brand-lockup">
          <img src={~p"/images/tracms-logo.svg"} alt="TRACMS logo" class="brand-logo" />
          <span class="brand-copy">
            <span class="eyebrow">DepEd Region IX</span>
            <span class="brand-title">TRACMS</span>
            <span class="brand-subtitle">
              Training, Registration, Attendance, and Certification Management System
            </span>
          </span>
        </.link>

        <nav class="nav-links" aria-label="Primary">
          <%= if @current_scope && @current_scope.user do %>
            <.link navigate={~p"/"} class="nav-link">Home</.link>
            <.link navigate={~p"/catalog/trainings"} class="nav-link">Catalog</.link>
            <.link navigate={~p"/my/registrations"} class="nav-link">My registrations</.link>
            <.link
              :if={Tracms.Accounts.Scope.training_manager?(@current_scope)}
              navigate={~p"/trainings"}
              class="nav-link"
            >
              Trainings
            </.link>
            <.link navigate={~p"/users/settings"} class="nav-link">Settings</.link>
            <span class="nav-user">{@current_scope.user.email}</span>
            <.button href={~p"/users/log-out"} method="delete" variant="ghost">Log out</.button>
          <% else %>
            <.link navigate={~p"/"} class="nav-link">Home</.link>
            <.button :if={@variant != "auth"} navigate={~p"/users/log-in"} variant="secondary">
              Log in
            </.button>
          <% end %>
        </nav>
      </div>
    </header>

    <header :if={@variant == "dashboard"} class="dashboard-header">
      <div class="dashboard-topbar-shell">
        <div class="dashboard-topbar">
          <.link navigate={~p"/dashboard"} class="brand-lockup">
            <img src={~p"/images/tracms-logo.svg"} alt="TRACMS logo" class="brand-logo" />
            <span class="brand-copy">
              <span class="eyebrow">Department of Education • Region IX</span>
              <span class="brand-title">TRACMS Portal</span>
              <span class="brand-subtitle">
                Training, Registration, Attendance, and Certification Management System
              </span>
            </span>
          </.link>

          <div class="dashboard-topbar-actions">
            <div class="dashboard-profile-card">
              <div class="dashboard-profile-avatar">{user_initials(@current_scope.user)}</div>
              <div class="dashboard-profile-copy">
                <span class="dashboard-profile-name">{user_display_name(@current_scope.user)}</span>
                <span class="dashboard-profile-role">{dashboard_role_label(@current_scope)}</span>
              </div>
            </div>
            <.button navigate={~p"/users/settings"} variant="ghost">Settings</.button>
            <.button href={~p"/users/log-out"} method="delete" variant="ghost">Log out</.button>
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
          <.link
            navigate={~p"/catalog/trainings"}
            class={dashboard_menu_link_class(@active_nav, "catalog")}
          >
            Registration
          </.link>
          <.link
            navigate={~p"/my/registrations"}
            class={dashboard_menu_link_class(@active_nav, "registrations")}
          >
            My Records
          </.link>
          <.link
            navigate={~p"/my/certificates"}
            class={dashboard_menu_link_class(@active_nav, "certificates")}
          >
            Certificates
          </.link>
          <.link
            :if={Tracms.Accounts.Scope.training_manager?(@current_scope)}
            navigate={~p"/trainings"}
            class={dashboard_menu_link_class(@active_nav, "trainings")}
          >
            Training Management
          </.link>
          <.link
            :if={Tracms.Accounts.Scope.training_manager?(@current_scope)}
            navigate={~p"/reports"}
            class={dashboard_menu_link_class(@active_nav, "reports")}
          >
            Reports
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

  defp dashboard_menu_link_class(active_nav, nav) do
    [
      "dashboard-menu-link",
      active_nav == nav && "dashboard-menu-link-active"
    ]
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

  defp dashboard_role_label(scope) do
    case scope.role_key do
      "regional_admin" -> "Regional Administrator"
      "division_admin" -> "Division Administrator"
      "training_coordinator" -> "Training Coordinator"
      "participant" -> "Participant"
      _ -> "Authorized User"
    end
  end

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
