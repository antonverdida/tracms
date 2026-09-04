defmodule TracmsWeb.UI.Card do
  use Phoenix.Component

  import TracmsWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, default: nil
  attr :variant, :atom, default: :basic, values: [:basic, :stat, :feature]
  attr :icon, :string, default: nil
  attr :title, :string, default: nil
  attr :description, :string, default: nil
  attr :value, :any, default: nil
  attr :trend, :string, default: nil
  attr :class, :any, default: nil

  slot :actions
  slot :inner_block
  slot :footer

  def card(assigns) do
    ~H"""
    <article id={@id} class={["ui-card", card_class(@variant), @class]}>
      <div :if={@icon || @title || @description || @value || @actions != []} class="ui-card-header">
        <div class="min-w-0">
          <div :if={@icon || @title} class="flex items-start gap-3">
            <div :if={@icon} class="ui-card-icon"><.icon name={@icon} class="size-5" /></div>
            <div>
              <h2 :if={@title} class="ui-card-title">{@title}</h2>
              <p :if={@description} class="ui-card-description">{@description}</p>
            </div>
          </div>
          <p :if={@value} class="ui-card-value">{@value}</p>
          <p :if={@trend} class="ui-card-trend">{@trend}</p>
        </div>
        <div :if={@actions != []} class="flex shrink-0 items-center gap-3">
          {render_slot(@actions)}
        </div>
      </div>
      <div :if={@inner_block != []} class="ui-card-content">{render_slot(@inner_block)}</div>
      <footer :if={@footer != []} class="ui-card-footer">{render_slot(@footer)}</footer>
    </article>
    """
  end

  defp card_class(:stat), do: "ui-card-stat"
  defp card_class(:feature), do: "ui-card-feature"
  defp card_class(:basic), do: "ui-card-basic"
end
