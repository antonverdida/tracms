defmodule TracmsWeb.UI.Modal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  import TracmsWeb.CoreComponents, only: [icon: 1]

  attr :id, :string, required: true
  attr :show, :boolean, default: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :on_cancel, JS, default: %JS{}
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :footer

  def modal(assigns) do
    ~H"""
    <div
      :if={@show}
      id={@id}
      class="ui-modal fixed inset-0 z-50 overflow-y-auto"
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      phx-window-keydown={@on_cancel}
      phx-key="escape"
    >
      <div class="ui-modal-backdrop fixed inset-0" aria-hidden="true" phx-click={@on_cancel}></div>
      <div class="flex min-h-full items-center justify-center p-4">
        <section
          class={["ui-modal-dialog relative w-full max-w-lg", @class]}
          phx-click-away={@on_cancel}
        >
          <header class="ui-modal-header">
            <div>
              <h2 id={"#{@id}-title"} class="ui-modal-title">{@title}</h2>
              <p :if={@description} class="ui-modal-description">{@description}</p>
            </div>
            <button
              id={"#{@id}-close"}
              type="button"
              class="ui-modal-close"
              aria-label="Close dialog"
              phx-click={@on_cancel}
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </header>
          <div class="ui-modal-content">{render_slot(@inner_block)}</div>
          <footer :if={@footer != []} class="ui-modal-footer">{render_slot(@footer)}</footer>
        </section>
      </div>
    </div>
    """
  end
end
