defmodule TracmsWeb.UserLive.LoginTest do
  use TracmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tracms.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Welcome Back!"
      assert html =~ "Security Notice"
      assert html =~ ~s(alt="TRACMS Region IX logo")
      refute html =~ "Secure Access"
      refute html =~ "Authorized DepEd Region IX personnel only."
      refute html =~ "Training Management"
      refute html =~ "Create, manage, and monitor training activities."
      refute html =~ "Send secure sign-in link"
      refute html =~ "Create account"
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{username: user.username, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/dashboard"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password", user: %{username: "test-user", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "The username or password you entered is incorrect."

      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with username filled in", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/users/log-in")

      assert html =~ "Secure Login"
      refute html =~ "Create account"
      refute html =~ "Send secure sign-in link"
      assert html =~ ~s(id="login_form_password_username")
      assert html =~ ~s(value="#{user.username}")
    end
  end
end
