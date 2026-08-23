defmodule TracmsWeb.PortalComponents do
  @moduledoc """
  Shared portal-oriented UI components for authenticated pages.
  """
  use Phoenix.Component
  import TracmsWeb.CoreComponents, only: [icon: 1]

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :copy, :string, default: nil

  slot :actions

  def portal_page_header(assigns) do
    ~H"""
    <section class="portal-page-head">
      <div class="portal-page-copy-block">
        <p class="eyebrow">{@eyebrow}</p>
        <h1 class="portal-page-title">{@title}</h1>
        <p :if={@copy} class="portal-page-copy">{@copy}</p>
      </div>

      <div :if={@actions != []} class="portal-page-actions">
        {render_slot(@actions)}
      </div>
    </section>
    """
  end

  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :copy, :string, default: nil
  attr :nav_items, :list, required: true

  slot :actions

  def training_workspace_header(assigns) do
    ~H"""
    <section class="space-y-5">
      <.portal_page_header eyebrow={@eyebrow} title={@title} copy={@copy}>
        <:actions>{render_slot(@actions)}</:actions>
      </.portal_page_header>

      <nav
        :if={@nav_items != []}
        aria-label="Training workspace"
        class="rounded-[28px] border border-slate-200 bg-white/90 p-3 shadow-sm"
      >
        <div class="flex flex-wrap gap-2">
          <.link
            :for={item <- @nav_items}
            navigate={item.path}
            class={[
              "inline-flex min-h-11 items-center rounded-full px-4 text-sm font-semibold transition",
              item.active? &&
                "bg-[var(--tracms-primary)] text-white shadow-[0_16px_30px_rgba(15,74,146,0.18)]",
              !item.active? &&
                "border border-slate-200 bg-slate-50 text-slate-600 hover:border-[var(--tracms-primary)] hover:text-[var(--tracms-primary)]"
            ]}
          >
            {item.label}
          </.link>
        </div>
      </nav>
    </section>
    """
  end

  attr :cards, :list, required: true

  def portal_stat_grid(assigns) do
    ~H"""
    <section class="portal-mini-stat-grid">
      <.portal_stat_card :for={card <- @cards} label={card.label} value={card.value} meta={card.meta} />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :meta, :string, default: nil

  def portal_stat_card(assigns) do
    ~H"""
    <article class="portal-mini-stat-card">
      <p class="portal-mini-stat-label">{@label}</p>
      <p class="portal-mini-stat-value">{@value}</p>
      <p :if={@meta} class="portal-mini-stat-meta">{@meta}</p>
    </article>
    """
  end

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :copy, :string, required: true

  slot :actions

  def portal_empty_state(assigns) do
    ~H"""
    <div class="portal-empty-state">
      <div class="portal-empty-icon">
        <.icon name={@icon} class="size-7" />
      </div>
      <div>
        <h2 class="portal-empty-title">{@title}</h2>
        <p class="section-copy portal-empty-copy">{@copy}</p>
      </div>
      <div :if={@actions != []} class="portal-empty-actions">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :meta, :string, default: nil

  slot :actions

  def portal_panel_header(assigns) do
    ~H"""
    <div class="portal-table-head">
      <div>
        <p :if={@eyebrow} class="eyebrow">{@eyebrow}</p>
        <h2 class="section-title">{@title}</h2>
      </div>

      <div class="flex items-center gap-3">
        <p :if={@meta} class="portal-table-meta">{@meta}</p>
        {render_slot(@actions)}
      </div>
    </div>
    """
  end
end
