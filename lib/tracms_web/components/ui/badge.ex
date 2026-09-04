defmodule TracmsWeb.UI.Badge do
  use Phoenix.Component

  import TracmsWeb.CoreComponents, only: [icon: 1]

  attr :tone, :atom, default: :info, values: [:info, :success, :warning, :danger, :neutral]
  attr :icon, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={["ui-badge", "portal-chip", "portal-chip-#{badge_tone(@tone)}", @class]}>
      <.icon :if={@icon} name={@icon} class="ui-badge-icon" />
      <span class="ui-badge-label">{render_slot(@inner_block)}</span>
    </span>
    """
  end

  defp badge_tone(:success), do: "green"
  defp badge_tone(:warning), do: "amber"
  defp badge_tone(:danger), do: "rose"
  defp badge_tone(:neutral), do: "slate"
  defp badge_tone(:info), do: "blue"
end
