defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLiveTest do
  alias PriceSpotter.Marketplaces
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotter.MarketplacesFixtures
  import PriceSpotterWeb.Gettext

  @create_attrs %{
    category: "some category",
    img_url: "some img_url",
    internal_id: "some internal_id #{System.unique_integer()}",
    name: "some name",
    price: "120.5",
    supplier_name: "some supplier_name",
    supplier_url: "some supplier_url"
  }
  @update_attrs %{
    category: "some updated category",
    img_url: "some updated img_url",
    internal_id: "some updated internal_id #{System.unique_integer()}",
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

  defp create_product(_context) do
    product = product_fixture()
    %{product: product |> PriceSpotter.Repo.preload(:supplier)}
  end

  defp assoc_user_product(context) do
    %{product: product, user: user} = context

    Marketplaces.create_user_supplier(%{
      user_id: user.id,
      supplier_id: product.supplier_id,
      role: :maintainer
    })

    %{}
  end

  defp assert_patch_path(view, expected_path) do
    %{path: path} = URI.parse(assert_patch(view))
    assert path == expected_path
  end

  describe "Index" do
    setup [:create_product, :register_and_log_in_admin, :assoc_user_product]

    test "lists all products", %{conn: conn, product: product} do
      {:ok, _index_live, html} = live(conn, ~p"/admin/marketplaces/products")

      assert html =~ gettext("Listing Products")
      assert html =~ product.category
    end

    test "does not render unassigned category chip and shows dash for missing price",
         %{
           conn: conn,
           user: user
         } do
      product =
        product_fixture(%{
          category: nil,
          internal_id: "missing-price-#{System.unique_integer([:positive])}",
          price: nil
        })

      Marketplaces.create_user_supplier(%{
        user_id: user.id,
        supplier_id: product.supplier_id,
        role: :maintainer
      })

      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")
      row_html = index_live |> element("#products-#{product.id}") |> render()

      refute row_html =~ gettext("Unassigned")
      refute row_html =~ gettext("No price yet")
      assert row_html =~ "–"
    end

    test "keeps price and details in place when the product name is long", %{
      conn: conn,
      user: user
    } do
      long_name =
        String.duplicate("Very long product name ", 8)
        |> String.trim()

      product =
        product_fixture(%{
          name: long_name,
          internal_id: "long-#{System.unique_integer([:positive])}"
        })

      Marketplaces.create_user_supplier(%{
        user_id: user.id,
        supplier_id: product.supplier_id,
        role: :maintainer
      })

      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")
      row_html = index_live |> element("#products-#{product.id}") |> render()

      assert row_html =~ long_name
      assert row_html =~ "$#{product.price}"

      assert has_element?(
               index_live,
               "#products-#{product.id}-toggle-expand",
               gettext("Details")
             )
    end

    test "saves new product", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      assert index_live
             |> element("a", gettext("New Product"))
             |> render_click() =~
               gettext("New Product")

      assert_patch(index_live, ~p"/admin/marketplaces/products/new")

      assert index_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#product-form", product: @create_attrs)
             |> render_submit()

      assert_patch_path(index_live, ~p"/admin/marketplaces/products")

      html = render(index_live)
      assert html =~ gettext("Product created successfully")
      assert html =~ "some category"
    end

    test "updates product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      html =
        index_live
        |> element("#products-#{product.id}-toggle-expand")
        |> render_click()

      assert_patch_path(
        index_live,
        ~p"/admin/marketplaces/products/#{product}/edit"
      )

      assert html =~ gettext("Show Product")
      assert has_element?(index_live, "#products-edit-form-#{product.id}")
      assert has_element?(index_live, "#product-form")

      assert index_live
             |> form("#product-form", product: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#product-form", product: @update_attrs)
             |> render_submit()

      assert_patch_path(index_live, ~p"/admin/marketplaces/products")

      html = render(index_live)
      assert html =~ gettext("Product updated successfully")
      assert html =~ @update_attrs[:category]
      assert html =~ @update_attrs[:name]
      assert html =~ @update_attrs[:price]
      assert html =~ @update_attrs[:supplier_name]
    end

    @tag :skip
    test "deletes product in listing", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      assert index_live
             |> element("a#products-delete-#{product.id}")
             |> render_click()

      # LiveView process exits after delete
      refute has_element?(index_live, "a#products-delete-#{product.id}")
    end
  end

  describe "Show" do
    setup [:create_product, :register_and_log_in_admin]

    test "displays product", %{conn: conn, product: product} do
      {:ok, _show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert html =~ gettext("Show Product")
      assert html =~ product.category
    end

    test "fills the selected price-history interval button", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert html =~ gettext("Daily")

      assert has_element?(
               show_live,
               ~s(button[phx-value-interval=daily][aria-pressed="true"])
             )

      show_live
      |> element("button[phx-value-interval=weekly]")
      |> render_click()

      assert has_element?(
               show_live,
               ~s(button[phx-value-interval=weekly][aria-pressed="true"])
             )

      refute has_element?(
               show_live,
               ~s(button[phx-value-interval=daily][aria-pressed="true"])
             )
    end

    test "updates product within modal", %{conn: conn, product: product} do
      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert show_live |> element("a#edit-button") |> render_click() =~
               gettext("Edit Product")

      assert_patch(
        show_live,
        ~p"/admin/marketplaces/products/#{product}/show/edit"
      )

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

    test "keeps supplier, category, and price in pills only", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}")

      assert html =~ product.supplier_name
      assert html =~ product.category
      assert html =~ "$#{product.price}"

      details =
        show_live
        |> element("#product-details-list")
        |> render()

      refute details =~ gettext("Supplier")
      refute details =~ gettext("Category")
      refute details =~ gettext("Price")
      assert details =~ gettext("EAN")
      assert details =~ gettext("External link")
    end

    test "does not render the EAN listings banner without other suppliers", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}")

      refute has_element?(show_live, "#ean-listings")
    end

    test "lists other-supplier EAN matches for an admin", %{
      conn: conn,
      product: product
    } do
      ean = "7790070418161"

      {:ok, current} = Marketplaces.update_product(product, %{ean: ean})

      other =
        product_fixture(%{
          ean: ean,
          internal_id: "other-#{System.unique_integer([:positive])}",
          name: "Other supplier listing",
          supplier_name: "other-supplier",
          price: "88.5"
        })

      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{current}")

      assert has_element?(show_live, "#ean-listings")
      assert html =~ gettext("Same product at other suppliers")
      assert html =~ other.name
      assert html =~ "$#{other.price}"
      assert html =~ gettext("Last price update")
      refute has_element?(show_live, "#ean-listings-hidden-count")

      assert has_element?(
               show_live,
               "#ean-listing-#{other.id} a[target=_blank]"
             )

      assert html =~ ~p"/admin/marketplaces/products/#{other}"
    end
  end

  describe "Show EAN listings for a customer" do
    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
    alias PriceSpotter.Marketplaces.SuppliersFixtures

    setup [:register_and_log_in_user]

    test "shows granted listings and a count of hidden suppliers", %{
      conn: conn,
      user: user
    } do
      ean = "7790070418161"
      granted_supplier = SuppliersFixtures.create()
      hidden_supplier = SuppliersFixtures.create()
      current_supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: current_supplier.id
      })

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      current =
        product_fixture(%{
          ean: ean,
          internal_id: "current-#{System.unique_integer([:positive])}",
          name: "Current listing",
          supplier_id: current_supplier.id,
          supplier_name: current_supplier.name
        })

      visible =
        product_fixture(%{
          ean: ean,
          internal_id: "visible-#{System.unique_integer([:positive])}",
          name: "Visible other listing",
          price: "77.1",
          supplier_id: granted_supplier.id,
          supplier_name: granted_supplier.name
        })

      hidden =
        product_fixture(%{
          ean: ean,
          internal_id: "hidden-#{System.unique_integer([:positive])}",
          name: "Hidden other listing",
          supplier_id: hidden_supplier.id,
          supplier_name: hidden_supplier.name
        })

      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{current}")

      assert html =~ visible.name
      assert html =~ "$#{visible.price}"
      refute html =~ hidden.name

      assert has_element?(show_live, "#ean-listings-hidden-count")

      assert html =~
               ngettext(
                 "%{count} more supplier sells this product",
                 "%{count} more suppliers sell this product",
                 1,
                 count: 1
               )
    end
  end
end
