defmodule TracmsWeb.UI.Alert do
  use Phoenix.Component

  import TracmsWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, default: nil
  attr :kind, :atom, default: :info, values: [:info, :success, :warning, :error]
  attr :title, :string, default: nil
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div id={@id} role="alert" class={["rounded-2xl border p-4", alert_class(@kind), @class]}>
      <div class="flex items-start gap-3">
        <.icon name={alert_icon(@kind)} class="mt-0.5 size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <div class="text-sm leading-6">{render_slot(@inner_block)}</div>
        </div>
      </div>
    </div>
    """
  end

  defp alert_icon(:success), do: "hero-check-circle"
  defp alert_icon(:warning), do: "hero-exclamation-triangle"
  defp alert_icon(:error), do: "hero-x-circle"
  defp alert_icon(:info), do: "hero-information-circle"

  defp alert_class(:success),
    do: "border-[var(--tracms-success)] bg-[var(--tracms-success-soft)] text-[var(--tracms-text)]"

  defp alert_class(:warning),
    do: "border-[var(--tracms-warning)] bg-[var(--tracms-warning-soft)] text-[var(--tracms-text)]"

  defp alert_class(:error),
    do: "border-[var(--tracms-danger)] bg-[var(--tracms-danger-soft)] text-[var(--tracms-text)]"

  defp alert_class(:info),
    do: "border-[var(--primary)] bg-[var(--tracms-primary-soft)] text-[var(--tracms-text)]"
end
