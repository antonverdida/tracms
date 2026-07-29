defmodule TracmsWeb.PortalLive.Documents do
  use TracmsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Documents")
     |> assign(:summary_cards, documents_summary_cards())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      variant="dashboard"
      active_nav="documents"
    >
      <div class="portal-page-shell">
        <.portal_page_header
          eyebrow="Documents"
          title="Document Center"
          copy="Access and manage TRACMS documents related to training, attendance, and certification."
        >
          <:actions>
            <.button navigate={~p"/dashboard"} variant="ghost">Back to dashboard</.button>
          </:actions>
        </.portal_page_header>

        <.portal_stat_grid cards={@summary_cards} />

        <section class="panel portal-list-panel">
          <.portal_panel_header
            eyebrow="Document workflows"
            title="Document repository"
            meta="Centralize training records, certificates, and reference materials for your office."
          />

          <div class="portal-empty-quiet">
            <p class="section-copy">
              This section will house TRACMS documents once they are available.
            </p>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp documents_summary_cards do
    [
      summary_card("Certificates", "—", "Issued certificate documents."),
      summary_card("Training records", "—", "Published training documentation."),
      summary_card("Forms", "—", "Forms and attachments available for download."),
      summary_card("Audit logs", "—", "Document access activity and history.")
    ]
  end
end
