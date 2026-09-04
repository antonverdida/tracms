defmodule TracmsWeb.UI.Panel do
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :string, default: nil

  slot :actions
  slot :inner_block, required: true
  slot :footer

  def panel(assigns) do
    ~H"""
    <section id={@id} class={["ui-panel panel portal-list-panel", @class]}>
      <div class="portal-table-head">
        <div>
          <p :if={@eyebrow} class="eyebrow">{@eyebrow}</p>
          <h2 class="section-title">{@title}</h2>
          <p :if={@description} class="portal-table-meta">{@description}</p>
        </div>
        <div :if={@actions != []} class="flex items-center gap-3">{render_slot(@actions)}</div>
      </div>
      <div class="ui-panel-content">{render_slot(@inner_block)}</div>
      <footer :if={@footer != []} class="mt-5 border-t border-[var(--tracms-border)] pt-4">
        {render_slot(@footer)}
      </footer>
    </section>
    """
  end
end
