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
      assert html =~ gettext("Last updated")
      assert html =~ product.category

      header_html =
        html
        |> String.split("tracking-wide")
        |> Enum.at(1)
        |> String.split("id=\"products\"")
        |> List.first()

      supplier_idx = :binary.match(header_html, gettext("Supplier")) |> elem(0)

      last_updated_idx =
        :binary.match(header_html, gettext("Last updated")) |> elem(0)

      assert supplier_idx < last_updated_idx
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
      assert row_html =~ TimeAgo.time_ago(product.price_updated_at)
      assert row_html =~ "min-w-0 truncate"

      refute row_html =~ gettext("Details")
      assert has_element?(index_live, "#products-#{product.id}-header")
      refute has_element?(index_live, "#products-#{product.id}-toggle-expand")
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

      index_live
      |> element("#products-#{product.id}-header")
      |> render_click()

      assert_patch_path(
        index_live,
        ~p"/admin/marketplaces/products/#{product}/edit"
      )

      assert has_element?(index_live, "#products-#{product.id}-preview")
      assert has_element?(index_live, "#products-analytics-#{product.id}")
      assert has_element?(index_live, "#products-edit-form-#{product.id}")
      assert has_element?(index_live, "#product-form-#{product.id}")

      assert has_element?(
               index_live,
               "#products-#{product.id}-expand[aria-hidden='false']"
             )

      header_html =
        index_live
        |> element("#products-#{product.id}-header")
        |> render()

      refute header_html =~ "$#{product.price}"

      assert index_live
             |> form("#product-form-#{product.id}", product: @invalid_attrs)
             |> render_change() =~ dgettext("errors", "can't be blank")

      assert index_live
             |> form("#product-form-#{product.id}", product: @update_attrs)
             |> render_submit()

      html = render(index_live)
      assert html =~ gettext("Product updated successfully")
      assert html =~ @update_attrs[:category]
      assert html =~ @update_attrs[:name]
      assert html =~ @update_attrs[:price]
      assert html =~ @update_attrs[:supplier_name]

      assert has_element?(
               index_live,
               "#products-#{product.id}-expand[aria-hidden='false']"
             )

      assert has_element?(index_live, "#product-form-#{product.id}")
    end

    test "keeps an expanded product visible when filters exclude it", %{
      conn: conn,
      user: user,
      product: product
    } do
      {:ok, {_products, meta}} =
        Marketplaces.list_products_by_user(
          %{
            "filters" => %{
              "0" => %{
                "field" => "name",
                "op" => "ilike",
                "value" => "no-such-product-xyz"
              }
            }
          },
          user
        )

      path =
        Flop.Phoenix.build_path(
          ~p"/admin/marketplaces/products/#{product}/edit",
          meta.flop,
          backend: meta.backend
        )

      {:ok, index_live, _html} = live(conn, path)

      assert has_element?(index_live, "#products-#{product.id}")

      assert has_element?(
               index_live,
               "#products-#{product.id}-expand[aria-hidden='false']"
             )
    end

    test "shows saved values when an expanded product is outside the current filters",
         %{
           conn: conn,
           user: user,
           product: product
         } do
      {:ok, {_products, meta}} =
        Marketplaces.list_products_by_user(
          %{
            "filters" => %{
              "0" => %{
                "field" => "name",
                "op" => "ilike",
                "value" => "no-such-product-xyz"
              }
            }
          },
          user
        )

      path =
        Flop.Phoenix.build_path(
          ~p"/admin/marketplaces/products/#{product}/edit",
          meta.flop,
          backend: meta.backend
        )

      {:ok, index_live, _html} = live(conn, path)

      assert index_live
             |> form("#product-form-#{product.id}", product: @update_attrs)
             |> render_submit()

      html =
        index_live
        |> element("#products-#{product.id}")
        |> render()

      assert html =~ @update_attrs[:name]
      refute html =~ product.name
    end

    test "replaces delete with a trash icon", %{conn: conn, product: product} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      index_live
      |> element("#products-#{product.id}-header")
      |> render_click()

      assert_patch_path(
        index_live,
        ~p"/admin/marketplaces/products/#{product}/edit"
      )

      assert has_element?(index_live, "#products-delete-#{product.id}")

      delete_html =
        index_live
        |> element("#products-delete-#{product.id}")
        |> render()

      assert delete_html =~ "hero-trash-solid"
      assert delete_html =~ "sr-only"
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

  describe "Index as customer" do
    setup [:create_product, :register_and_log_in_user, :assoc_user_product]

    test "expands a product without the edit form or /edit redirect", %{
      conn: conn,
      product: product
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      html =
        index_live
        |> element("#products-#{product.id}-header")
        |> render_click()

      assert_patch_path(
        index_live,
        ~p"/admin/marketplaces/products/#{product}"
      )

      assert has_element?(
               index_live,
               "#products-#{product.id}-expand[aria-hidden='false']"
             )

      assert has_element?(index_live, "#products-#{product.id}-preview")
      assert html =~ "$#{product.price}"
      assert html =~ TimeAgo.time_ago(product.price_updated_at)
      refute has_element?(index_live, "#products-edit-form-#{product.id}")
      refute has_element?(index_live, "#product-form-#{product.id}")
      refute has_element?(index_live, "#products-delete-#{product.id}")

      index_live
      |> element("#products-#{product.id}-header")
      |> render_click()

      assert_patch_path(index_live, ~p"/admin/marketplaces/products")

      assert has_element?(
               index_live,
               "#products-#{product.id}-expand[aria-hidden='true']"
             )
    end

    test "does not delete a product when a customer pushes delete", %{
      conn: conn,
      product: product
    } do
      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      html = render_click(index_live, "delete", %{"id" => product.id})

      assert Marketplaces.get_product!(product.id).id == product.id
      assert html =~ gettext("You are not allowed to delete products")
    end

    test "does not crash when a customer pushes delete for an ungranted product",
         %{
           conn: conn
         } do
      other =
        product_fixture(%{
          internal_id: "foreign-#{System.unique_integer([:positive])}"
        })

      {:ok, index_live, _html} = live(conn, ~p"/admin/marketplaces/products")

      html = render_click(index_live, "delete", %{"id" => other.id})

      assert Marketplaces.get_product!(other.id).id == other.id
      assert html =~ gettext("You are not allowed to delete products")
    end
  end

  describe "Show" do
    setup [:create_product, :register_and_log_in_admin]

    test "displays product", %{conn: conn, product: product} do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

      assert html =~ gettext("Show Product")
      assert html =~ product.category
      assert html =~ "sticky top-0"
      assert html =~ "overflow-x-clip overscroll-none px-4 pb-2"

      refute html =~
               "overflow-x-clip overscroll-none px-4 pb-2 sm:px-6 lg:px-8 pt-2"

      edit_html = show_live |> element("#edit-button") |> render()
      assert edit_html =~ "hero-pencil-solid"
      assert edit_html =~ "sr-only"
      assert has_element?(show_live, "a#edit-button")
      refute has_element?(show_live, "a#edit-button button")

      delete_html = show_live |> element("#delete-button") |> render()
      assert delete_html =~ "hero-trash-solid"
      assert delete_html =~ "sr-only"
      assert has_element?(show_live, "button#delete-button")
      refute has_element?(show_live, "a#delete-button")
    end

    test "fills the selected price-history interval button", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

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
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

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

      assert_patch(
        show_live,
        ~p"/admin/marketplaces/products/#{product}/show"
      )

      html = render(show_live)
      assert html =~ gettext("Product updated successfully")
      assert html =~ "some updated category"
    end

    test "shows supplier, category, and price in the details card", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

      details =
        show_live
        |> element("#product-details-list")
        |> render()

      assert details =~ gettext("Supplier")
      assert details =~ String.replace(product.supplier_name, "-", " ")
      assert details =~ gettext("Category")
      assert details =~ product.category
      assert details =~ gettext("Price")
      assert details =~ "$#{product.price}"
      assert details =~ gettext("EAN")
      assert details =~ gettext("External link")
      refute html =~ gettext("Product information")
    end

    test "renders present meta fields and skips empty or internal ones", %{
      conn: conn,
      product: product
    } do
      {:ok, product} =
        Marketplaces.update_product(product, %{
          meta: %{
            "stock" => true,
            "list_price" => "6865.00",
            "price_per_kg" => "21357.78",
            "price_without_taxes" => "5674.38",
            "origen" => "seed-dev",
            "crawl_index" => 12,
            "empty" => nil
          }
        })

      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

      details =
        show_live
        |> element("#product-details-list")
        |> render()

      assert has_element?(show_live, "#product-meta-stock")
      assert details =~ gettext("Stock")
      assert details =~ gettext("In stock")
      assert details =~ gettext("List price")
      assert details =~ "$6865.00"
      assert details =~ gettext("Price per kg")
      assert details =~ "$21357.78"
      assert details =~ gettext("Price without taxes")
      assert details =~ "$5674.38"
      refute has_element?(show_live, "#product-meta-origen")
      refute has_element?(show_live, "#product-meta-crawl_index")
      refute has_element?(show_live, "#product-meta-empty")
      refute details =~ "seed-dev"
    end

    test "does not render the EAN listings banner without other suppliers", %{
      conn: conn,
      product: product
    } do
      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

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
          category: "snacks",
          price: "88.5",
          meta: %{
            "stock" => true,
            "price_per_kg" => "21357.78"
          }
        })

      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{current}/show")

      listing =
        show_live
        |> element("#ean-listing-#{other.id}")
        |> render()

      assert has_element?(show_live, "#ean-listings")
      assert html =~ gettext("Same product at other suppliers")
      assert listing =~ "other supplier"
      assert listing =~ "snacks"
      assert listing =~ gettext("Stock")
      assert listing =~ gettext("In stock")
      assert listing =~ gettext("Price per kg")
      assert listing =~ "$21357.78"
      assert listing =~ "$#{other.price}"
      assert listing =~ "−$32.0 (−26.6%)"
      assert listing =~ TimeAgo.time_ago(other.price_updated_at)
      assert listing =~ "hero-shopping-cart-solid"

      assert listing =~
               gettext("Open %{supplier} listing", supplier: "other supplier")

      refute listing =~ ">#{other.name}<"
      refute listing =~ "77 90070 41816 1"
      refute has_element?(show_live, "#ean-listings-hidden-count")

      assert has_element?(
               show_live,
               "#ean-listing-#{other.id} a[target=_blank]"
             )

      assert listing =~ ~p"/admin/marketplaces/products/#{other}/show"
      assert has_element?(show_live, "#ean-listing-#{other.id} img")
    end

    test "pushes chart series labeled with supplier names only", %{
      conn: conn,
      product: product
    } do
      ean = "7790070418161"

      {:ok, current} = Marketplaces.update_product(product, %{ean: ean})

      other =
        product_fixture(%{
          ean: ean,
          internal_id: "chart-#{System.unique_integer([:positive])}",
          name: "Other supplier listing",
          supplier_name: "other-supplier"
        })

      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{current}/show")

      %{proxy: {ref, _topic, _}} = show_live

      assert_receive {^ref,
                      {:push_event, "set-chart-data", %{datasets: datasets}}},
                     1000

      labels = Enum.map(datasets, & &1.label)

      assert String.replace(current.supplier_name, "-", " ") in labels
      assert String.replace(other.supplier_name, "-", " ") in labels
      refute other.name in labels
    end

    test "shows a green signed delta when another supplier is more expensive",
         %{
           conn: conn,
           product: product
         } do
      ean = "7790070418161"

      {:ok, current} = Marketplaces.update_product(product, %{ean: ean})

      other =
        product_fixture(%{
          ean: ean,
          internal_id: "expensive-#{System.unique_integer([:positive])}",
          name: "Expensive supplier listing",
          supplier_name: "expensive-supplier",
          price: "241.0"
        })

      {:ok, show_live, _html} =
        live(conn, ~p"/admin/marketplaces/products/#{current}/show")

      listing =
        show_live
        |> element("#ean-listing-#{other.id}")
        |> render()

      assert listing =~ "+$120.5 (+100.0%)"
      assert listing =~ "text-emerald-600"
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
        live(conn, ~p"/admin/marketplaces/products/#{current}/show")

      listing =
        show_live
        |> element("#ean-listing-#{visible.id}")
        |> render()

      assert listing =~ String.replace(visible.supplier_name, "-", " ")
      assert listing =~ "$#{visible.price}"
      assert listing =~ "−$43.4 (−36.0%)"
      refute listing =~ ">#{visible.name}<"
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

    test "returns 404 when the product belongs to a supplier the customer cannot access",
         %{
           conn: conn,
           user: user
         } do
      granted_supplier = SuppliersFixtures.create()
      other_supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      _granted =
        product_fixture(%{
          internal_id: "granted-#{System.unique_integer([:positive])}",
          supplier_id: granted_supplier.id,
          supplier_name: granted_supplier.name
        })

      other =
        product_fixture(%{
          internal_id: "foreign-#{System.unique_integer([:positive])}",
          supplier_id: other_supplier.id,
          supplier_name: other_supplier.name
        })

      assert_error_sent 404, fn ->
        live(conn, ~p"/admin/marketplaces/products/#{other}/show")
      end
    end

    test "does not delete a product when a customer pushes delete", %{
      conn: conn,
      user: user
    } do
      supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: supplier.id
      })

      product =
        product_fixture(%{
          internal_id: "owned-#{System.unique_integer([:positive])}",
          supplier_id: supplier.id,
          supplier_name: supplier.name
        })

      {:ok, show_live, html} =
        live(conn, ~p"/admin/marketplaces/products/#{product}/show")

      refute has_element?(show_live, "#delete-button")
      refute html =~ ~s(id="delete-button")

      html = render_click(show_live, "delete", %{})

      assert Marketplaces.get_product!(product.id).id == product.id
      assert html =~ gettext("You are not allowed to delete products")
    end
  end
end
