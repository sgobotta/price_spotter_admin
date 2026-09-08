defmodule PriceSpotterWeb.Admin.Accounts.UserLiveTest do
  use PriceSpotterWeb.ConnCase

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
  alias PriceSpotter.Marketplaces.SuppliersFixtures

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

    test "toggles expanded controls for a user", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      html =
        index_live
        |> element("#users-#{user.id}-toggle-expand")
        |> render_click()

      assert html =~ "users-#{user.id}-expand"

      assert has_element?(
               index_live,
               "#users-#{user.id}-expand[aria-hidden='false']"
             )

      html =
        index_live
        |> element("#users-#{user.id}-toggle-expand")
        |> render_click()

      assert html =~ "users-#{user.id}-expand"

      assert has_element?(
               index_live,
               "#users-#{user.id}-expand[aria-hidden='true']"
             )
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

      index_live
      |> element("#users-#{user.id}-toggle-expand")
      |> render_click()

      assert index_live
             |> form("#user-form-#{user.id}", user: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#user-form-#{user.id}", user: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/accounts/users")

      html = render(index_live)
      assert html =~ gettext("User updated successfully")
      assert html =~ "some_updated@email"
    end

    test "expanded row does not render separate show/edit actions", %{
      conn: conn,
      user: user
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      index_live
      |> element("#users-#{user.id}-toggle-expand")
      |> render_click()

      refute has_element?(index_live, "a#users-edit-#{user.id}")

      refute has_element?(
               index_live,
               "a[href='/admin/accounts/users/#{user.id}']"
             )

      assert has_element?(index_live, "#user-form-#{user.id}")
    end

    test "customer access can be managed from the expanded row", %{
      conn: conn,
      user: user
    } do
      supplier = SuppliersFixtures.create()

      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      html =
        index_live
        |> element("#users-#{user.id}-toggle-expand")
        |> render_click()

      ref = extract_row_ref(html)

      index_live
      |> element("#customer-access-form-#{user.id}")
      |> render_submit(%{
        "rows" => %{
          to_string(ref) => %{
            "supplier_id" => supplier.id,
            "role" => "maintainer"
          }
        }
      })

      html = render(index_live)
      assert html =~ gettext("Customer access updated successfully")
      assert html =~ supplier.name
      assert html =~ "maintainer"

      assert [%{supplier_id: supplier_id, role: :maintainer}] =
               Marketplaces.list_user_suppliers_for_user(user)

      assert supplier_id == supplier.id
    end

    test "deletes user in listing", %{conn: conn, user: user} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/accounts/users")

      index_live
      |> element("#users-#{user.id}-toggle-expand")
      |> render_click()

      html =
        index_live
        |> element("#users-delete-#{user.id}")
        |> render_click()

      assert html =~ gettext("Delete user")
      assert html =~ user.email

      assert index_live
             |> element("#delete-user-modal button[phx-click='delete']")
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

  describe "Customer access" do
    setup [:register_and_log_in_admin, :create_user]

    test "renders empty state when the user has no supplier access", %{
      conn: conn,
      user: user
    } do
      {:ok, _show_live, html} = live(conn, ~p"/admin/accounts/users/#{user}")

      assert html =~ gettext("Customer access")
      assert html =~ gettext("No supplier access granted yet.")
    end

    test "adding another row renders a second set of supplier/role selects",
         %{conn: conn, user: user} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/accounts/users/#{user}")

      html =
        show_live
        |> element("button", "+ Add another")
        |> render_click()

      assert length(Regex.scan(~r/id="row-\d+-supplier"/, html)) == 2
    end

    test "saving a row grants the supplier access to the user", %{
      conn: conn,
      user: user
    } do
      supplier = SuppliersFixtures.create()

      {:ok, show_live, html} = live(conn, ~p"/admin/accounts/users/#{user}")
      ref = extract_row_ref(html)

      show_live
      |> element("#customer-access-form")
      |> render_submit(%{
        "rows" => %{
          to_string(ref) => %{
            "supplier_id" => supplier.id,
            "role" => "maintainer"
          }
        }
      })

      html = render(show_live)
      assert html =~ gettext("Customer access updated successfully")
      assert html =~ supplier.name
      assert html =~ "maintainer"

      assert [%{supplier_id: supplier_id, role: :maintainer}] =
               Marketplaces.list_user_suppliers_for_user(user)

      assert supplier_id == supplier.id
    end

    test "saving an already-granted supplier surfaces a per-row error and keeps existing grants",
         %{conn: conn, user: user} do
      supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: supplier.id,
        role: :maintainer
      })

      {:ok, show_live, html} = live(conn, ~p"/admin/accounts/users/#{user}")
      ref = extract_row_ref(html)

      html =
        show_live
        |> element("#customer-access-form")
        |> render_submit(%{
          "rows" => %{
            to_string(ref) => %{
              "supplier_id" => supplier.id,
              "role" => "consumer"
            }
          }
        })

      assert html =~ "has already been taken"

      assert [%{role: :maintainer}] =
               Marketplaces.list_user_suppliers_for_user(user)
    end

    test "removing a grant deletes it", %{conn: conn, user: user} do
      supplier = SuppliersFixtures.create()

      user_supplier =
        UsersSuppliersFixtures.create(%{
          user_id: user.id,
          supplier_id: supplier.id
        })

      {:ok, show_live, _html} = live(conn, ~p"/admin/accounts/users/#{user}")

      html =
        show_live
        |> element(
          "a[phx-click=remove_grant][phx-value-id='#{user_supplier.id}']"
        )
        |> render_click()

      assert html =~ gettext("No supplier access granted yet.")
      assert Marketplaces.list_user_suppliers_for_user(user) == []
    end
  end

  defp extract_row_ref(html) do
    [_, ref] = Regex.run(~r/id="row-(\d+)-supplier"/, html)
    String.to_integer(ref)
  end
end
