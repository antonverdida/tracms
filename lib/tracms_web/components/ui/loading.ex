defmodule TracmsWeb.UI.Loading do
  use Phoenix.Component

  attr :label, :string, default: "Loading..."
  attr :class, :string, default: nil

  def loading(assigns) do
    ~H"""
    <div
      role="status"
      class={["flex items-center gap-3 text-sm font-medium text-[var(--tracms-text-muted)]", @class]}
    >
      <span class="size-5 animate-spin rounded-full border-2 border-[var(--tracms-border)] border-t-[var(--primary)]">
      </span>
      <span>{@label}</span>
    </div>
    """
  end
end
