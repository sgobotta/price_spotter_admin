defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotter.MarketplacesFixtures
  import PriceSpotterWeb.Gettext

  @create_attrs %{
    category: "some category",
    img_url: "some img_url",
    internal_id: "some internal_id",
    name: "some name",
    price: "120.5",
    supplier_name: "some supplier_name",
    supplier_url: "some supplier_url"
  }
  @update_attrs %{
    category: "some updated category",
    img_url: "some updated img_url",
    internal_id: "some updated internal_id",
    name: "some updated name",
    price: "456.7",
    supplier_name: "some updated supplier_name",
    supplier_url: "some updated supplier_url"
  }
  @invalid_attrs %{
    category: nil,
    img_url: nil,
    internal_id: nil,
    name: nil,
    price: nil,
    supplier_name: nil,
    supplier_url: nil
  }

  defp create_product(_) do
    product = product_fixture()
    %{product: product}
  end

  describe "Index" do
    setup [:create_product]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/marketplaces/products")

      assert html =~ gettext("Listing Products")
      assert html =~ product.category
    end

    @tag :skip
    test "saves new product", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      assert index_live |> element("a", gettext("New Product")) |> render_click() =~
               gettext("New Product")

      assert_patch(index_live, ~p"/admin/marketplaces/products/new")

      assert index_live
             |> form("#product-form", product: @invalid_attrs)
             #  |> render_change() =~ "can&#39;t be blank"
             |> render_change() =~ "no puede estar en blanco"

      assert index_live
             |> form("#product-form", product: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/products")

      html = render(index_live)
      assert html =~ "Product created successfully"
      assert html =~ "some category"
    end

    @tag :skip
    test "updates product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      assert index_live |> element("#products-#{product.id} a", "Edit") |> render_click() =~
               "Edit Product"

      assert_patch(index_live, ~p"/admin/marketplaces/products/#{product}/edit")

      assert index_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#product-form", product: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/admin/marketplaces/products")

      html = render(index_live)
      assert html =~ "Product updated successfully"
      assert html =~ "some updated category"
    end

    @tag :skip
    test "deletes product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      assert index_live |> element("#products-#{product.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#products-#{product.id}")
    end
  end

  describe "Show" do
    setup [:create_product]

    test "displays product", %{conn: conn, product: product} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert html =~ gettext("Show Product")
      assert html =~ product.category
    end

    test "updates product within modal", %{conn: conn, product: product} do
      {:ok, show_live, _html} = live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert show_live |> element("a#edit-button") |> render_click() =~
               gettext("Edit Product")

      assert_patch(show_live, ~p"/admin/marketplaces/products/#{product}/show/edit")

      assert show_live
             |> form("#product-form", product: @invalid_attrs)
             #  |> render_change() =~ gettext("can't be blank")
             |> render_change() =~ gettext("no puede estar en blanco")

      assert show_live
             |> form("#product-form", product: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/admin/marketplaces/products/#{product}")

      html = render(show_live)
      assert html =~ gettext("Product updated successfully")
      assert html =~ "some updated category"
    end
  end
end
