defmodule TracmsWeb.PortalLiveTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "dashboard navigation" do
    test "manager sees the full top menu", %{conn: conn} do
      %{user: user} = Tracms.TrainingsFixtures.training_manager_scope_fixture()

      html =
        conn
        |> log_in_user(user)
        |> get(~p"/dashboard")
        |> html_response(200)

      assert html =~ "Dashboard"
      assert html =~ "Training Management"
      assert html =~ "Registrations"
      assert html =~ "Certificates"
      assert html =~ "Reports"
      assert html =~ "Documents"
      assert html =~ "Settings"
    end

    test "participant sees the common portal menu", %{conn: conn} do
      user = Tracms.AccountsFixtures.user_fixture()

      html =
        conn
        |> log_in_user(user)
        |> get(~p"/dashboard")
        |> html_response(200)

      assert html =~ "Dashboard"
      assert html =~ "Registrations"
      assert html =~ "Certificates"
      assert html =~ "Documents"
      assert html =~ "Settings"
      refute html =~ "Training Management"
      refute html =~ "Reports"
    end
  end

  describe "portal placeholders" do
    test "renders the documents page for authenticated users", %{conn: conn} do
      user = Tracms.AccountsFixtures.user_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/documents")

      assert html =~ "Document Center"
      assert html =~ "Document Center"
      assert html =~ "Document repository"
    end

    test "renders the Google Integration page for managers", %{conn: conn} do
      %{user: user} = Tracms.TrainingsFixtures.training_manager_scope_fixture()

      {:ok, _lv, html} =
        conn
        |> log_in_user(user)
        |> live(~p"/google-integration")

      assert html =~ "Google Workspace Integration"
      assert html =~ "Integration status"
    end
  end
end
