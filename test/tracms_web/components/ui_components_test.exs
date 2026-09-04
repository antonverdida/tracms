defmodule TracmsWeb.UIComponentsTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest
  import TracmsWeb.UI.Alert
  import TracmsWeb.UI.Badge
  import TracmsWeb.UI.Card
  import TracmsWeb.UI.DataTable
  import TracmsWeb.UI.Loading
  import TracmsWeb.UI.Modal
  import TracmsWeb.UI.Panel

  test "renders shared panel, badge, alert, and loading primitives" do
    html = render_component(&render_primitives/1)

    assert html =~ "ui-panel"
    assert html =~ "ui-panel-content"
    assert html =~ "Completed"
    assert html =~ "ui-badge"
    assert html =~ "hero-check-circle"
    assert html =~ "Deadline"
    assert html =~ "Saving..."
  end

  test "renders shared card, data table, and modal primitives" do
    html = render_component(&render_composite_primitives/1)

    assert html =~ "Training statistics"
    assert html =~ "ICT Fundamentals"
    assert html =~ "No records have been added."
    assert html =~ "Loading training records..."
    assert html =~ "loading-records-loading"
    assert html =~ "Confirm approval"
  end

  defp render_primitives(assigns) do
    _ = assigns

    ~H"""
    <.panel id="ui-panel" title="Training summary">Content</.panel>
    <.badge tone={:success} icon="hero-check-circle">Completed</.badge>
    <.alert kind={:warning} title="Deadline">Review the schedule.</.alert>
    <.loading label="Saving..." />
    """
  end

  defp render_composite_primitives(assigns) do
    _ = assigns

    ~H"""
    <.card variant={:stat} title="Training statistics" value="120" trend="12 this month" />
    <.data_table
      id="training-records"
      rows={[%{id: 1, title: "ICT Fundamentals"}]}
      row_id={fn row -> "training-#{row.id}" end}
    >
      <:col :let={row} label="Title">{row.title}</:col>
    </.data_table>
    <.data_table id="empty-records" rows={[]} empty?={true}>
      <:col :let={_row} label="Title">Unused</:col>
      <:empty>No records have been added.</:empty>
    </.data_table>
    <.data_table id="loading-records" rows={[]} loading?={true}>
      <:col :let={_row} label="Title">Unused</:col>
      <:loading>Loading training records...</:loading>
    </.data_table>
    <.modal id="approval-modal" title="Confirm approval" on_cancel={Phoenix.LiveView.JS.push("close")}>
      Approve this registration?
    </.modal>
    """
  end
end
