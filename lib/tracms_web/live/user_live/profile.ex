defmodule TracmsWeb.UserLive.Profile do
  use TracmsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="dashboard"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Profile"
          title={profile_name(@current_scope.user)}
          copy="Manage your administrator profile and account details."
        >
          <:actions>
            <.button navigate={~p"/users/settings"} variant="secondary">Edit Settings</.button>
          </:actions>
        </.portal_page_header>

        <div class="content-grid">
          <section class="panel portal-list-panel md:col-span-2">
            <.portal_panel_header eyebrow="Account" title="Administrator Profile" />

            <div class="grid gap-4 md:grid-cols-2">
              <div class="feature-card">
                <div class="feature-title">Full Name</div>
                <div class="feature-copy">{profile_name(@current_scope.user)}</div>
              </div>

              <div class="feature-card">
                <div class="feature-title">Email</div>
                <div class="feature-copy">{@current_scope.user.email}</div>
              </div>

              <div class="feature-card">
                <div class="feature-title">Office</div>
                <div class="feature-copy">{office_name(@current_scope.user)}</div>
              </div>

              <div class="feature-card">
                <div class="feature-title">Division</div>
                <div class="feature-copy">{division_name(@current_scope.user)}</div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp profile_name(%{full_name: full_name}) when is_binary(full_name) and full_name != "",
    do: full_name

  defp profile_name(_user), do: "Administrator"

  defp office_name(%{office: office}) when not is_nil(office), do: office.name
  defp office_name(_user), do: "Not assigned"

  defp division_name(%{office: %{division: division}}) when not is_nil(division),
    do: division.name

  defp division_name(_user), do: "Not assigned"
end
