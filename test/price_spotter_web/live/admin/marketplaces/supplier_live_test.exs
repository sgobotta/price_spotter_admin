defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotterWeb.Gettext

  alias PriceSpotter.Marketplaces.SuppliersFixtures

  @create_attrs SuppliersFixtures.valid_attrs()
  @update_attrs SuppliersFixtures.update_attrs()
  @invalid_attrs SuppliersFixtures.invalid_attrs()

  defp create_supplier(_context) do
    supplier = SuppliersFixtures.create()
    %{supplier: supplier}
  end

  describe "Index" do
    setup [:create_supplier, :register_and_log_in_admin]

    test "lists all suppliers", %{conn: conn, supplier: supplier} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert html =~ gettext("Listing Suppliers")
      assert html =~ supplier.name
    end

    test "toggles expanded controls for a supplier", %{
      conn: conn,
      supplier: supplier
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert has_element?(
               index_live,
               "#suppliers-#{supplier.id}-header[role='button']"
             )

      html =
        index_live
        |> element("#suppliers-#{supplier.id}-header")
        |> render_click()

      assert html =~ "suppliers-#{supplier.id}-expand"

      assert has_element?(
               index_live,
               "#suppliers-#{supplier.id}-expand[aria-hidden='false']"
             )

      html =
        index_live
        |> element("#suppliers-#{supplier.id}-header")
        |> render_click()

      assert html =~ "suppliers-#{supplier.id}-expand"

      assert has_element?(
               index_live,
               "#suppliers-#{supplier.id}-expand[aria-hidden='true']"
             )
    end

    test "saves new supplier", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert index_live
             |> element("a", gettext("New Supplier"))
             |> render_click() =~
               gettext("New Supplier")

      assert_patch(index_live, ~p"/admin/marketplaces/suppliers/new")

      assert index_live
             |> form("#supplier-form", supplier: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#supplier-form", supplier: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/suppliers")

      html = render(index_live)
      assert html =~ gettext("Supplier created successfully")
      assert html =~ @create_attrs.name
    end

    test "updates supplier in listing", %{conn: conn, supplier: supplier} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      index_live
      |> element("#suppliers-#{supplier.id}-header")
      |> render_click()

      assert index_live
             |> element("a#suppliers-edit-#{supplier.id}")
             |> render_click() =~
               gettext("Edit Supplier")

      assert_patch(
        index_live,
        ~p"/admin/marketplaces/suppliers/#{supplier}/edit"
      )

      assert index_live
             |> form("#supplier-form", supplier: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#supplier-form", supplier: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/suppliers")

      html = render(index_live)
      assert html =~ gettext("Supplier updated successfully")
      assert html =~ "some updated name"
    end

    test "deletes supplier in listing", %{conn: conn, supplier: supplier} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      index_live
      |> element("#suppliers-#{supplier.id}-header")
      |> render_click()

      assert index_live
             |> element("#suppliers-delete-#{supplier.id}")
             |> render_click()

      refute has_element?(index_live, "#suppliers-#{supplier.id}")
    end
  end

  describe "Show" do
    setup [:create_supplier, :register_and_log_in_admin]

    test "displays supplier", %{conn: conn, supplier: supplier} do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/suppliers/#{supplier}")

      assert html =~ gettext("Show Supplier")
      assert html =~ supplier.name
      assert html =~ gettext("Subscribed")
      assert has_element?(show_live, "#supplier-subscribed")
      assert html =~ "hero-check-circle-solid"
    end

    test "updates supplier within modal", %{conn: conn, supplier: supplier} do
      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/suppliers/#{supplier}")

      assert show_live |> element("a", gettext("Edit")) |> render_click() =~
               gettext("Edit Supplier")

      assert_patch(
        show_live,
        ~p"/admin/marketplaces/suppliers/#{supplier}/show/edit"
      )

      assert show_live
             |> form("#supplier-form", supplier: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert show_live
             |> form("#supplier-form", supplier: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/marketplaces/suppliers/#{supplier}")

      html = render(show_live)
      assert html =~ gettext("Supplier updated successfully")
      assert html =~ "some updated name"
    end
  end

  describe "Index as customer" do
    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures

    setup [:register_and_log_in_user]

    test "shows suppliers in the sidebar", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert has_element?(index_live, "nav a", gettext("Suppliers"))
    end

    test "shows an empty-access message when the user has no suppliers", %{
      conn: conn
    } do
      {:ok, _index_live, html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert html =~ gettext("You don't have access to any suppliers.")
      refute html =~ gettext("New Supplier")
    end

    test "lists only granted suppliers and hides admin actions", %{
      conn: conn,
      user: user
    } do
      granted = SuppliersFixtures.create()
      other = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted.id
      })

      {:ok, index_live, html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert html =~ granted.name
      refute html =~ other.name
      refute html =~ gettext("New Supplier")
      refute has_element?(index_live, "#suppliers-edit-#{granted.id}")
      refute has_element?(index_live, "#suppliers-delete-#{granted.id}")
    end

    test "redirects away from the new supplier page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/marketplaces/suppliers/new")
    end
  end

  describe "Show as customer" do
    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures

    setup [:register_and_log_in_user]

    test "displays a granted supplier without edit actions", %{
      conn: conn,
      user: user
    } do
      granted = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted.id
      })

      {:ok, _show_live, html} =
        live(conn, ~p"/admin/marketplaces/suppliers/#{granted}")

      assert html =~ gettext("Show Supplier")
      assert html =~ granted.name
      assert html =~ gettext("Subscribed")
      assert html =~ "hero-check-circle-solid"
      refute html =~ gettext("Edit supplier")
    end

    test "shows an ungranted supplier as not subscribed", %{conn: conn} do
      other = SuppliersFixtures.create()

      {:ok, _show_live, html} =
        live(conn, ~p"/admin/marketplaces/suppliers/#{other}")

      assert html =~ other.name
      assert html =~ gettext("Subscribed")
      assert html =~ "hero-x-circle-solid"
      refute html =~ gettext("Edit supplier")
    end
  end
end
