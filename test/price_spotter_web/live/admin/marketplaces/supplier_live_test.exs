defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotterWeb.Gettext

  alias PriceSpotter.Marketplaces.SuppliersFixtures

  @create_attrs SuppliersFixtures.valid_attrs()
  @update_attrs SuppliersFixtures.update_attrs()
  @invalid_attrs SuppliersFixtures.invalid_attrs()

  defp create_supplier(_) do
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

    test "saves new supplier", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers")

      assert index_live |> element("a", gettext("New Supplier")) |> render_click() =~
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

      assert index_live
             |> element("a#suppliers-edit-#{supplier.id}")
             |> render_click() =~
               gettext("Edit Supplier")

      assert_patch(index_live, ~p"/admin/marketplaces/suppliers/#{supplier}/edit")

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

      assert index_live
             |> element("a#suppliers-delete-#{supplier.id}")
             |> render_click()

      refute has_element?(index_live, "#suppliers-#{supplier.id}")
    end
  end

  describe "Show" do
    setup [:create_supplier, :register_and_log_in_admin]

    test "displays supplier", %{conn: conn, supplier: supplier} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/marketplaces/suppliers/#{supplier}")

      assert html =~ gettext("Show Supplier")
      assert html =~ supplier.name
    end

    test "updates supplier within modal", %{conn: conn, supplier: supplier} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/marketplaces/suppliers/#{supplier}")

      assert show_live |> element("a", gettext("Edit")) |> render_click() =~
               gettext("Edit Supplier")

      assert_patch(show_live, ~p"/admin/marketplaces/suppliers/#{supplier}/show/edit")

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
end
