defmodule TracmsWeb.PortalLive.GoogleIntegration do
  use TracmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Google Integration")
     |> assign(:summary_cards, google_integration_summary_cards())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="google_integration"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Google Integration"
          title="Google Workspace Integration"
          copy="Monitor TRACMS connections with Google Forms and Sheets for registration and attendance workflows."
        >
          <:actions>
            <.button navigate={~p"/dashboard"} variant="ghost">Back to dashboard</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Integration status"
            title="Active connections"
            meta="Review the status of Google Form and Sheet sync links."
          />

          <div class="portal-empty-quiet">
            <p class="section-copy">
              Training-specific Google integration details are managed from the training record. This overview summarizes the current connection status.
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp google_integration_summary_cards do
    [
      summary_card("Forms connected", "—", "Google Forms connected to TRACMS."),
      summary_card("Sheets connected", "—", "Google Sheets synced with TRACMS data."),
      summary_card("Sync errors", "—", "Sync failures over the last 24 hours."),
      summary_card("Integration health", "—", "Current Google Workspace integration status.")
    ]
  end
end
