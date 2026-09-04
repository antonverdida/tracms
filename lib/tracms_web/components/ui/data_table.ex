defmodule TracmsWeb.UI.DataTable do
  use Phoenix.Component
  use Gettext, backend: TracmsWeb.Gettext

  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :row_id, :any, default: nil
  attr :row_item, :any, default: &Function.identity/1
  attr :row_click, :any, default: nil
  attr :empty?, :boolean, default: false
  attr :loading?, :boolean, default: false
  attr :class, :string, default: nil

  slot :col, required: true do
    attr :label, :string, required: true
  end

  slot :action
  slot :empty
  slot :loading

  def data_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div id={"#{@id}-table"} class={["ui-data-table", @class]} aria-busy={to_string(@loading?)}>
      <div
        :if={@loading?}
        id={"#{@id}-loading"}
        class="ui-data-table-state"
        role="status"
      >
        {render_slot(@loading) || gettext("Loading records...")}
      </div>
      <div :if={!@loading? && @empty?} id={"#{@id}-empty"} class="ui-data-table-state">
        {render_slot(@empty) || gettext("No records found.")}
      </div>
      <div :if={!@loading? && !@empty?} class="data-table-wrap">
        <table class="data-table">
          <thead>
            <tr>
              <th :for={col <- @col}>{col.label}</th>
              <th :if={@action != []}><span class="sr-only">{gettext("Actions")}</span></th>
            </tr>
          </thead>
          <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
            <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
              <td
                :for={col <- @col}
                phx-click={@row_click && @row_click.(row)}
                class={@row_click && "cursor-pointer"}
              >
                {render_slot(col, @row_item.(row))}
              </td>
              <td :if={@action != []} class="w-0 font-semibold">
                <div class="flex gap-3">
                  <%= for action <- @action do %>
                    {render_slot(action, @row_item.(row))}
                  <% end %>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
