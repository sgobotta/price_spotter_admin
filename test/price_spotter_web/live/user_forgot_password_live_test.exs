defmodule PriceSpotterWeb.UserForgotPasswordLiveTest do
  use PriceSpotterWeb.ConnCase

  import PriceSpotterWeb.Gettext

  import Phoenix.LiveViewTest
  import PriceSpotter.AccountsFixtures

  alias PriceSpotter.Accounts
  alias PriceSpotter.Repo

  describe "Forgot password page" do
    test "renders email page", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/users/reset_password")

      assert html =~ gettext("Forgot your password?")
      assert has_element?(lv, ~s|a[href="#{~p"/users/register"}"]|, gettext("Register"))
      assert has_element?(lv, ~s|a[href="#{~p"/users/log_in"}"]|, gettext("Log in"))
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/reset_password")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end
  end

  describe "Reset link" do
    setup do
      %{user: user_fixture()}
    end

    test "sends a new reset password token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", user: %{"email" => user.email})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext(
                 "If your email is in our system, you will receive instructions to reset your password shortly."
               )

      assert Repo.get_by!(Accounts.UserToken, user_id: user.id).context ==
               "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/reset_password")

      {:ok, conn} =
        lv
        |> form("#reset_password_form", user: %{"email" => "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               gettext(
                 "If your email is in our system, you will receive instructions to reset your password shortly."
               )

      assert Repo.all(Accounts.UserToken) == []
    end
  end
end
