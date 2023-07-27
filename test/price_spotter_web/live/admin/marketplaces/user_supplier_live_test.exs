defmodule PriceSpotterWeb.Admin.Marketplaces.UserSupplierLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotterWeb.Gettext

  alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures

  @update_attrs UsersSuppliersFixtures.update_attrs()
  @invalid_attrs UsersSuppliersFixtures.invalid_attrs()

  defp create_user_supplier(_) do
    %{user_supplier: UsersSuppliersFixtures.create()}
  end

  describe "Index" do
    setup [:create_user_supplier, :register_and_log_in_admin]

    test "lists all users_suppliers", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/marketplaces/users_suppliers")

      assert html =~ gettext("Listing Users suppliers")
    end

    test "saves new user_supplier", %{conn: conn} do
      %PriceSpotter.Accounts.User{id: user_id} = PriceSpotter.AccountsFixtures.user_fixture()

      %PriceSpotter.Marketplaces.Supplier{id: supplier_id} =
        PriceSpotter.Marketplaces.SuppliersFixtures.create()

      create_attrs =
        UsersSuppliersFixtures.valid_attrs(%{user_id: user_id, supplier_id: supplier_id})

      invalid_attrs =
        UsersSuppliersFixtures.invalid_attrs(%{user_id: user_id, supplier_id: supplier_id})

      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/users_suppliers")

      assert index_live |> element("a", gettext("New User supplier")) |> render_click() =~
               gettext("New User supplier")

      assert_patch(index_live, ~p"/admin/marketplaces/users_suppliers/new")

      assert index_live
             |> form("#user_supplier-form", user_supplier: invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#user_supplier-form", user_supplier: create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/users_suppliers")

      html = render(index_live)
      assert html =~ gettext("User supplier created successfully")
    end

    test "updates user_supplier in listing", %{conn: conn, user_supplier: user_supplier} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/users_suppliers")

      assert index_live
             |> element("#users_suppliers-#{user_supplier.id} a", "Edit")
             |> render_click() =~
               gettext("Edit User supplier")

      assert_patch(index_live, ~p"/admin/marketplaces/users_suppliers/#{user_supplier}/edit")

      assert index_live
             |> form("#user_supplier-form", user_supplier: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#user_supplier-form", user_supplier: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/users_suppliers")

      html = render(index_live)
      assert html =~ gettext("User supplier updated successfully")
    end

    test "deletes user_supplier in listing", %{conn: conn, user_supplier: user_supplier} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/users_suppliers")

      assert index_live
             |> element("#users_suppliers-#{user_supplier.id} a", gettext("Delete"))
             |> render_click()

      refute has_element?(index_live, "#users_suppliers-#{user_supplier.id}")
    end
  end

  describe "Show" do
    setup [:create_user_supplier, :register_and_log_in_admin]

    test "displays user_supplier", %{conn: conn, user_supplier: user_supplier} do
      {:ok, _show_live, html} =
        live(conn, ~p"/admin/marketplaces/users_suppliers/#{user_supplier}")

      assert html =~ gettext("Show User supplier")
    end

    test "updates user_supplier within modal", %{conn: conn, user_supplier: user_supplier} do
      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/users_suppliers/#{user_supplier}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               gettext("Edit User supplier")

      assert_patch(show_live, ~p"/admin/marketplaces/users_suppliers/#{user_supplier}/show/edit")

      assert show_live
             |> form("#user_supplier-form", user_supplier: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert show_live
             |> form("#user_supplier-form", user_supplier: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/marketplaces/users_suppliers/#{user_supplier}")

      html = render(show_live)
      assert html =~ gettext("User supplier updated successfully")
    end
  end
end
