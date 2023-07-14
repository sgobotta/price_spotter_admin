defmodule PriceSpotterWeb.UserRegistrationLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotter.AccountsFixtures
  import PriceSpotterWeb.Gettext

  describe "Registration page" do
    @tag :skip
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ gettext("Register")
      assert html =~ gettext("Log in")
    end

    @tag :skip
    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    @tag :skip
    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ gettext("Register for an account")
      assert result =~ dgettext("errors", "must have the @ sign and no spaces")

      assert result =~
               dgettext("errors", "should be between %{min} and %{max} characters",
                 min: 12,
                 max: 72
               )
    end
  end

  describe "register user" do
    @tag :skip
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))
      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ gettext("Settings")
      assert response =~ gettext("Log out")
    end

    @tag :skip
    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ dgettext("errors", "has already been taken")
    end
  end

  describe "registration navigation" do
    @tag :skip
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      msg = gettext("Sign in")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a:fl-contains("#{msg}")|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ gettext("Log in")
    end
  end
end
