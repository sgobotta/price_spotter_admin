defmodule PriceSpotterWeb.Admin.Accounts.UserLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotter.AccountsFixtures
  import PriceSpotterWeb.Gettext

  @create_attrs %{email: "some@email", password: "some password", role: :user}
  @update_attrs %{
    email: "some_updated@email",
    password: "some updated password",
    role: :admin
  }
  @invalid_attrs %{email: nil, password: nil, role: nil}

  defp create_user(_context) do
    user = user_fixture()
    %{user: user}
  end

  describe "Index" do
    setup [:register_and_log_in_admin, :create_user]

    test "lists all users", %{conn: conn, user: user} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/accounts/users")

      assert html =~ gettext("Users")
      assert html =~ user.email
    end

    test "saves new user", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      assert index_live |> element("a", gettext("New User")) |> render_click() =~
               gettext("New User")

      assert_patch(index_live, ~p"/admin/accounts/users/new")

      assert index_live
             |> form("#user-form", user: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#user-form", user: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/accounts/users")

      html = render(index_live)
      assert html =~ gettext("User created successfully")
      assert html =~ "some@email"
    end

    test "updates user in listing", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      assert index_live |> element("a#users-edit-#{user.id}") |> render_click() =~
               gettext("Edit User")

      assert_patch(index_live, ~p"/admin/accounts/users/#{user}/edit")

      assert index_live
             |> form("#user-form", user: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#user-form", user: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/accounts/users")

      html = render(index_live)
      assert html =~ gettext("User updated successfully")
      assert html =~ "some_updated@email"
    end

    test "deletes user in listing", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      assert index_live
             |> element("a#users-delete-#{user.id}")
             |> render_click()

      refute has_element?(index_live, "#users-#{user.id}")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_admin, :create_user]

    test "displays user", %{conn: conn, user: user} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/accounts/users/#{user}")

      assert html =~ gettext("Show User")
      assert html =~ user.email
    end

    test "updates user within modal", %{conn: conn, user: user} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/accounts/users/#{user}")

      assert show_live |> element("a", gettext("Edit")) |> render_click() =~
               gettext("Edit User")

      assert_patch(show_live, ~p"/admin/accounts/users/#{user}/show/edit")

      assert show_live
             |> form("#user-form", user: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert show_live
             |> form("#user-form", user: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/accounts/users/#{user}")

      html = render(show_live)
      assert html =~ gettext("User updated successfully")
      assert html =~ "some_updated@email"
    end
  end
end
