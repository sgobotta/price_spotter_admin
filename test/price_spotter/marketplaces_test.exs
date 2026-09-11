defmodule PriceSpotter.MarketplacesTest do
  alias PriceSpotter.Marketplaces.Supplier
  use PriceSpotter.DataCase

  alias PriceSpotter.Marketplaces

  describe "products" do
    alias PriceSpotter.Marketplaces.Product

    import PriceSpotter.MarketplacesFixtures

    @invalid_attrs %{
      category: nil,
      img_url: nil,
      internal_id: nil,
      meta: nil,
      name: nil,
      price: nil,
      supplier_name: nil,
      supplier_url: nil
    }

    test "list_products/0 returns all products" do
      product = product_fixture()
      assert Marketplaces.list_products() == [product]
    end

    test "get_product!/1 returns the product with given id" do
      product = product_fixture()
      assert Marketplaces.get_product!(product.id) == product
    end

    test "create_product/1 with valid data creates a product" do
      valid_attrs = %{
        category: "some category",
        img_url: "some img_url",
        internal_id: "some internal_id",
        meta: %{},
        name: "some name",
        price: "120.5",
        supplier_name: "some supplier_name",
        supplier_url: "some supplier_url"
      }

      assert {:ok, %Product{} = product} =
               Marketplaces.create_product(valid_attrs)

      assert product.category == "some category"
      assert product.img_url == "some img_url"
      assert product.internal_id == "some internal_id"
      assert product.meta == %{}
      assert product.name == "some name"
      assert product.price == Decimal.new("120.5")
      assert product.supplier_name == "some supplier_name"
      assert product.supplier_url == "some supplier_url"
    end

    test "create_product/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.create_product(@invalid_attrs)
    end

    test "update_product/2 with valid data updates the product" do
      product = product_fixture()

      update_attrs = %{
        category: "some updated category",
        img_url: "some updated img_url",
        internal_id: "some updated internal_id",
        meta: %{},
        name: "some updated name",
        price: "456.7",
        supplier_name: "some updated supplier_name",
        supplier_url: "some updated supplier_url"
      }

      assert {:ok, %Product{} = product} =
               Marketplaces.update_product(product, update_attrs)

      assert product.category == "some updated category"
      assert product.img_url == "some updated img_url"
      assert product.internal_id == "some updated internal_id"
      assert product.meta == %{}
      assert product.name == "some updated name"
      assert product.price == Decimal.new("456.7")
      assert product.supplier_name == "some updated supplier_name"
      assert product.supplier_url == "some updated supplier_url"
    end

    test "update_product/2 with invalid data returns error changeset" do
      product = product_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.update_product(product, @invalid_attrs)

      assert product == Marketplaces.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Marketplaces.delete_product(product)

      assert_raise Ecto.NoResultsError, fn ->
        Marketplaces.get_product!(product.id)
      end
    end

    test "change_product/1 returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Marketplaces.change_product(product)
    end

    test "upsert_product/1 updates a product when the product already exists" do
      # Setup
      product = product_fixture()
      update_attrs = update_attrs(%{internal_id: product.internal_id})
      cs = Marketplaces.change_product(product, update_attrs)

      # Exercise
      result = Marketplaces.upsert_product(cs)

      # Verify
      assert {:ok, {:updated, product}} = result
      assert product.category == update_attrs.category
      assert product.img_url == update_attrs.img_url
      assert product.internal_id == update_attrs.internal_id
      assert product.meta == %{}
      assert product.name == update_attrs.name
      assert product.price == Decimal.new(update_attrs.price)
      assert product.supplier_name == update_attrs.supplier_name
      assert product.supplier_url == update_attrs.supplier_url
    end

    test "from_entry!/1 treats unpriced as a valid missing price" do
      entry = %Redis.Stream.Entry{
        id: "1-0",
        datetime: DateTime.utc_now(),
        values: %{
          "ean_code" => "7790070418161",
          "category" => "almacen",
          "img_url" => "https://example.com/img.png",
          "internal_id" => "carrefour-unpriced-1",
          "meta" => "{}",
          "name" => "Some product",
          "price" => "unpriced",
          "supplier" => "carrefour",
          "supplier_url" => "https://www.carrefour.com.ar/p/1"
        }
      }

      changeset = Product.from_entry!(entry)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :price) == nil
    end

    test "record_product_price/2 skips history writes when the product has no price" do
      product =
        product_fixture(%{
          internal_id: "unpriced-#{System.unique_integer()}",
          price: nil
        })

      assert {:ok, :skipped} = Marketplaces.record_product_price(product)

      refute Repo.exists?(
               from(s in Marketplaces.ProductPriceSnapshot,
                 where: s.product_id == ^product.id
               )
             )
    end

    test "upsert_product/1 creates a product when the product does not exist" do
      # Setup
      valid_attrs = valid_attrs()
      cs = Marketplaces.change_product(%Product{}, valid_attrs)

      # Exercise
      result = Marketplaces.upsert_product(cs)

      # Verify
      assert {:ok, {:created, product}} = result
      assert product.category == valid_attrs.category
      assert product.img_url == valid_attrs.img_url
      assert product.internal_id == valid_attrs.internal_id
      assert product.meta == %{}
      assert product.name == valid_attrs.name
      assert product.price == Decimal.new(valid_attrs.price)
      assert product.supplier_name == valid_attrs.supplier_name
      assert product.supplier_url == valid_attrs.supplier_url

      assert %Supplier{id: supplier_id} =
               PriceSpotter.Repo.get_by(Supplier,
                 name: valid_attrs.supplier_name
               )

      assert product.supplier_id == supplier_id
    end

    test "upsert_supplier/1 creates a supplier when the supplier does not exist" do
      # Setup
      valid_attrs = valid_attrs()
      cs = Marketplaces.change_product(%Product{}, valid_attrs)

      # Exercise
      result = Marketplaces.upsert_product(cs)

      # Verify
      assert {:ok,
              {:created, %Product{id: product_id, supplier_id: supplier_id}}} =
               result

      %{supplier_name: supplier_name} = valid_attrs

      assert %Supplier{id: ^supplier_id, name: ^supplier_name} =
               PriceSpotter.Repo.get_by(Supplier, name: supplier_name)

      assert %Product{supplier_id: ^supplier_id} =
               Marketplaces.get_product!(product_id)
    end

    test "upsert_supplier/1 does nothing when the supplier already exists" do
      # Setup
      %{supplier_name: supplier_name} = valid_attrs = valid_attrs()

      %Supplier{} =
        PriceSpotter.Marketplaces.SuppliersFixtures.create(%{
          name: supplier_name
        })

      cs = Marketplaces.change_product(%Product{}, valid_attrs)

      # Exercise
      result = Marketplaces.upsert_product(cs)

      # Verify
      assert {:ok,
              {:created, %Product{id: product_id, supplier_id: supplier_id}}} =
               result

      assert %Supplier{id: ^supplier_id, name: ^supplier_name} =
               PriceSpotter.Repo.get_by(Supplier, name: supplier_name)

      assert %Product{supplier_id: ^supplier_id} =
               Marketplaces.get_product!(product_id)
    end
  end

  describe "products by user" do
    import PriceSpotter.MarketplacesFixtures

    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
    alias PriceSpotter.Marketplaces.SuppliersFixtures

    test "list_products_by_user/2 returns every product for an admin, regardless of customer access" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      product = product_fixture()

      assert {:ok, {[result], _meta}} =
               Marketplaces.list_products_by_user(%{}, admin)

      assert result.id == product.id
    end

    test "list_products_by_user/2 scopes a non-admin user to their granted suppliers" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      granted_supplier = SuppliersFixtures.create()
      other_supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      granted_product =
        product_fixture(%{
          internal_id: "granted-#{System.unique_integer()}",
          supplier_id: granted_supplier.id
        })

      _other_product =
        product_fixture(%{
          internal_id: "other-#{System.unique_integer()}",
          supplier_id: other_supplier.id
        })

      assert {:ok, {[result], _meta}} =
               Marketplaces.list_products_by_user(%{}, user)

      assert result.id == granted_product.id
    end

    test "list_product_categories_by_user/1 returns every category for an admin" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      product_fixture(%{category: "some category"})

      assert Marketplaces.list_product_categories_by_user(admin) == [
               "some category"
             ]
    end

    test "list_product_categories_by_user/1 scopes a non-admin user to their granted suppliers" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      granted_supplier = SuppliersFixtures.create()
      other_supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      product_fixture(%{
        internal_id: "granted-#{System.unique_integer()}",
        category: "granted category",
        supplier_id: granted_supplier.id
      })

      product_fixture(%{
        internal_id: "other-#{System.unique_integer()}",
        category: "other category",
        supplier_id: other_supplier.id
      })

      assert Marketplaces.list_product_categories_by_user(user) == [
               "granted category"
             ]
    end

    test "list_suppliers_by_user/1 returns every supplier name for an admin" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      supplier = SuppliersFixtures.create()

      assert Marketplaces.list_suppliers_by_user(admin) == [supplier.name]
    end

    test "list_suppliers_by_user/1 scopes a non-admin user to their granted suppliers" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      granted_supplier = SuppliersFixtures.create()
      _other_supplier = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      assert Marketplaces.list_suppliers_by_user(user) == [
               granted_supplier.name
             ]
    end
  end

  describe "other ean listings" do
    import PriceSpotter.MarketplacesFixtures

    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
    alias PriceSpotter.Marketplaces.SuppliersFixtures

    @ean "7790070418161"

    defp listing_product(attrs) do
      unique = System.unique_integer([:positive])

      product_fixture(
        Map.merge(
          %{
            ean: @ean,
            internal_id: "ean-#{unique}",
            name: "Product #{unique}",
            supplier_name: "supplier-#{unique}"
          },
          attrs
        )
      )
    end

    test "returns empty listings when the product has no EAN" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      product = product_fixture()

      assert Marketplaces.list_other_ean_listings(product, user) == %{
               visible: [],
               hidden_supplier_count: 0
             }
    end

    test "admins see every other-supplier listing and no hidden count" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      current = listing_product(%{})

      visible =
        listing_product(%{
          name: "Visible listing",
          price: "88.5"
        })

      _same_supplier =
        listing_product(%{
          supplier_id: current.supplier_id,
          supplier_name: current.supplier_name,
          name: "Same supplier listing"
        })

      assert %{visible: [result], hidden_supplier_count: 0} =
               Marketplaces.list_other_ean_listings(current, admin)

      assert result.id == visible.id
    end

    test "non-admins see granted listings and a distinct hidden supplier count" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      granted_supplier = SuppliersFixtures.create()
      hidden_supplier_a = SuppliersFixtures.create()
      hidden_supplier_b = SuppliersFixtures.create()

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      current = listing_product(%{})

      visible =
        listing_product(%{
          name: "Granted listing",
          supplier_id: granted_supplier.id,
          supplier_name: granted_supplier.name
        })

      _hidden_a =
        listing_product(%{
          name: "Hidden listing A",
          supplier_id: hidden_supplier_a.id,
          supplier_name: hidden_supplier_a.name
        })

      _hidden_b1 =
        listing_product(%{
          name: "Hidden listing B1",
          supplier_id: hidden_supplier_b.id,
          supplier_name: hidden_supplier_b.name
        })

      _hidden_b2 =
        listing_product(%{
          name: "Hidden listing B2",
          supplier_id: hidden_supplier_b.id,
          supplier_name: hidden_supplier_b.name
        })

      assert %{visible: [result], hidden_supplier_count: 2} =
               Marketplaces.list_other_ean_listings(current, user)

      assert result.id == visible.id
    end

    test "treats unassigned listings as other suppliers by name" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()

      current =
        listing_product(%{
          supplier_id: nil,
          supplier_name: "unassigned-shop"
        })

      assigned =
        listing_product(%{
          name: "Assigned listing"
        })

      other_unassigned =
        listing_product(%{
          name: "Other unassigned listing",
          supplier_id: nil,
          supplier_name: "another-unassigned-shop"
        })

      _same_unassigned_supplier =
        listing_product(%{
          name: "Same unassigned supplier",
          supplier_id: nil,
          supplier_name: "unassigned-shop"
        })

      assert %{visible: results, hidden_supplier_count: 0} =
               Marketplaces.list_other_ean_listings(current, admin)

      result_ids = MapSet.new(results, & &1.id)

      assert MapSet.member?(result_ids, assigned.id)
      assert MapSet.member?(result_ids, other_unassigned.id)
      refute MapSet.member?(result_ids, current.id)
      refute Enum.any?(results, &(&1.supplier_name == current.supplier_name))
    end

    test "includes unassigned listings for a product with a supplier" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      current = listing_product(%{})

      unassigned =
        listing_product(%{
          name: "Unassigned listing",
          supplier_id: nil,
          supplier_name: "unassigned-shop"
        })

      assert %{visible: [result], hidden_supplier_count: 0} =
               Marketplaces.list_other_ean_listings(current, admin)

      assert result.id == unassigned.id
    end
  end

  describe "homepage metrics" do
    import PriceSpotter.MarketplacesFixtures

    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
    alias PriceSpotter.Marketplaces.SuppliersFixtures

    test "get_homepage_metrics/1 computes top movers from latest and previous snapshots" do
      admin = PriceSpotter.AccountsFixtures.admin_fixture()
      supplier = SuppliersFixtures.create()
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      up_product =
        product_fixture(%{
          internal_id: "up-#{System.unique_integer()}",
          name: "Up Product",
          supplier_name: supplier.name,
          supplier_id: supplier.id
        })

      down_product =
        product_fixture(%{
          internal_id: "down-#{System.unique_integer()}",
          name: "Down Product",
          supplier_name: supplier.name,
          supplier_id: supplier.id
        })

      same_product =
        product_fixture(%{
          internal_id: "same-#{System.unique_integer()}",
          name: "Same Product",
          supplier_name: supplier.name,
          supplier_id: supplier.id
        })

      new_product =
        product_fixture(%{
          internal_id: "new-#{System.unique_integer()}",
          name: "New Product",
          supplier_name: supplier.name,
          supplier_id: supplier.id
        })

      old_product =
        product_fixture(%{
          internal_id: "old-#{System.unique_integer()}",
          name: "Old Product",
          supplier_name: supplier.name,
          supplier_id: supplier.id
        })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: up_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("100.00"),
                 scraped_at: NaiveDateTime.add(now, -2 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: up_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("130.00"),
                 scraped_at: NaiveDateTime.add(now, -1 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: down_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("200.00"),
                 scraped_at: NaiveDateTime.add(now, -3 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: down_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("150.00"),
                 scraped_at: NaiveDateTime.add(now, -2 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: same_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("90.00"),
                 scraped_at: NaiveDateTime.add(now, -4 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: same_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("90.00"),
                 scraped_at: NaiveDateTime.add(now, -1 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: new_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("30.00"),
                 scraped_at: NaiveDateTime.add(now, -30 * 60, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: old_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("75.00"),
                 scraped_at: NaiveDateTime.add(now, -30 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: old_product.id,
                 supplier_id: supplier.id,
                 price: Decimal.new("80.00"),
                 scraped_at: NaiveDateTime.add(now, -29 * 3600, :second)
               })

      metrics = Marketplaces.get_homepage_metrics(admin)

      assert metrics.total_products == 5
      assert metrics.products_scraped_last_24h == 4
      assert metrics.products_price_increase_last_24h == 1
      assert metrics.products_price_decrease_last_24h == 1
      assert metrics.top_price_increase.product_name == "Up Product"
      assert metrics.top_price_decrease.product_name == "Down Product"
      assert metrics.top_price_increase.absolute_delta == Decimal.new("30.00")
      assert metrics.top_price_decrease.absolute_delta == Decimal.new("-50.00")
    end

    test "get_homepage_metrics/1 applies customer access scope to counts and cards" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      granted_supplier = SuppliersFixtures.create()
      other_supplier = SuppliersFixtures.create()
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      UsersSuppliersFixtures.create(%{
        user_id: user.id,
        supplier_id: granted_supplier.id
      })

      granted_product =
        product_fixture(%{
          internal_id: "granted-#{System.unique_integer()}",
          name: "Granted Product",
          supplier_name: granted_supplier.name,
          supplier_id: granted_supplier.id
        })

      other_product =
        product_fixture(%{
          internal_id: "other-#{System.unique_integer()}",
          name: "Other Product",
          supplier_name: other_supplier.name,
          supplier_id: other_supplier.id
        })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: granted_product.id,
                 supplier_id: granted_supplier.id,
                 price: Decimal.new("100.00"),
                 scraped_at: NaiveDateTime.add(now, -2 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: granted_product.id,
                 supplier_id: granted_supplier.id,
                 price: Decimal.new("120.00"),
                 scraped_at: NaiveDateTime.add(now, -1 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: other_product.id,
                 supplier_id: other_supplier.id,
                 price: Decimal.new("80.00"),
                 scraped_at: NaiveDateTime.add(now, -2 * 3600, :second)
               })

      assert {:ok, _} =
               Marketplaces.create_product_price_snapshot(%{
                 product_id: other_product.id,
                 supplier_id: other_supplier.id,
                 price: Decimal.new("120.00"),
                 scraped_at: NaiveDateTime.add(now, -1 * 3600, :second)
               })

      metrics = Marketplaces.get_homepage_metrics(user)

      assert metrics.total_products == 1
      assert metrics.products_scraped_last_24h == 1
      assert metrics.products_price_increase_last_24h == 1
      assert metrics.products_price_decrease_last_24h == 0
      assert metrics.top_price_increase.product_name == "Granted Product"
      assert metrics.top_price_decrease == nil
    end
  end

  describe "suppliers" do
    alias PriceSpotter.Marketplaces.Supplier

    alias PriceSpotter.Marketplaces.SuppliersFixtures

    @invalid_attrs %{name: nil}

    test "list_suppliers/0 returns all suppliers" do
      supplier = SuppliersFixtures.create()
      assert Marketplaces.list_suppliers() == [supplier]
    end

    test "get_supplier!/1 returns the supplier with given id" do
      supplier = SuppliersFixtures.create()
      assert Marketplaces.get_supplier!(supplier.id) == supplier
    end

    test "create_supplier/1 with valid data creates a supplier" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Supplier{} = supplier} =
               Marketplaces.create_supplier(valid_attrs)

      assert supplier.name == "some name"
    end

    test "create_supplier/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.create_supplier(@invalid_attrs)
    end

    test "update_supplier/2 with valid data updates the supplier" do
      supplier = SuppliersFixtures.create()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Supplier{} = supplier} =
               Marketplaces.update_supplier(supplier, update_attrs)

      assert supplier.name == "some updated name"
    end

    test "update_supplier/2 with invalid data returns error changeset" do
      supplier = SuppliersFixtures.create()

      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.update_supplier(supplier, @invalid_attrs)

      assert supplier == Marketplaces.get_supplier!(supplier.id)
    end

    test "delete_supplier/1 deletes the supplier" do
      supplier = SuppliersFixtures.create()
      assert {:ok, %Supplier{}} = Marketplaces.delete_supplier(supplier)

      assert_raise Ecto.NoResultsError, fn ->
        Marketplaces.get_supplier!(supplier.id)
      end
    end

    test "change_supplier/1 returns a supplier changeset" do
      supplier = SuppliersFixtures.create()
      assert %Ecto.Changeset{} = Marketplaces.change_supplier(supplier)
    end
  end

  describe "users_suppliers" do
    alias PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures
    alias PriceSpotter.Marketplaces.Relations.UserSupplier

    import PriceSpotter.MarketplacesFixtures

    test "list_user_suppliers_for_user/1 returns the user's grants preloaded with supplier" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      user_supplier = UsersSuppliersFixtures.create(%{user_id: user.id})

      assert [result] = Marketplaces.list_user_suppliers_for_user(user)
      assert result.id == user_supplier.id
      assert %PriceSpotter.Marketplaces.Supplier{} = result.supplier
    end

    test "get_user_supplier!/1 returns the user_supplier with given id" do
      user_supplier = UsersSuppliersFixtures.create()
      assert Marketplaces.get_user_supplier!(user_supplier.id) == user_supplier
    end

    test "create_user_supplier/1 with valid data creates a user_supplier" do
      %PriceSpotter.Accounts.User{id: user_id} =
        PriceSpotter.AccountsFixtures.user_fixture()

      %PriceSpotter.Marketplaces.Supplier{id: supplier_id} =
        PriceSpotter.Marketplaces.SuppliersFixtures.create()

      valid_attrs =
        UsersSuppliersFixtures.valid_attrs(%{
          user_id: user_id,
          supplier_id: supplier_id
        })

      assert {:ok, %UserSupplier{} = user_supplier} =
               Marketplaces.create_user_supplier(valid_attrs)

      assert user_supplier.role == valid_attrs.role
    end

    test "create_user_supplier/1 with invalid data returns error changeset" do
      invalid_attrs = UsersSuppliersFixtures.invalid_attrs()

      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.create_user_supplier(invalid_attrs)
    end

    test "update_user_supplier/2 with valid data updates the user_supplier" do
      user_supplier = UsersSuppliersFixtures.create()
      update_attrs = UsersSuppliersFixtures.update_attrs()

      assert {:ok, %UserSupplier{} = user_supplier} =
               Marketplaces.update_user_supplier(user_supplier, update_attrs)

      assert user_supplier.role == update_attrs.role
    end

    test "update_user_supplier/2 with invalid data returns error changeset" do
      user_supplier = UsersSuppliersFixtures.create()
      invalid_attrs = UsersSuppliersFixtures.invalid_attrs()

      assert {:error, %Ecto.Changeset{}} =
               Marketplaces.update_user_supplier(user_supplier, invalid_attrs)

      assert user_supplier == Marketplaces.get_user_supplier!(user_supplier.id)
    end

    test "delete_user_supplier/1 deletes the user_supplier" do
      user_supplier = UsersSuppliersFixtures.create()

      assert {:ok, %UserSupplier{}} =
               Marketplaces.delete_user_supplier(user_supplier)

      assert_raise Ecto.NoResultsError, fn ->
        Marketplaces.get_user_supplier!(user_supplier.id)
      end
    end

    test "change_user_supplier/1 returns a user_supplier changeset" do
      user_supplier = UsersSuppliersFixtures.create()

      assert %Ecto.Changeset{} =
               Marketplaces.change_user_supplier(user_supplier)
    end

    test "create_user_suppliers/2 inserts one row per entry for the given user" do
      user = PriceSpotter.AccountsFixtures.user_fixture()

      %{id: supplier_id_1} =
        PriceSpotter.Marketplaces.SuppliersFixtures.create()

      %{id: supplier_id_2} =
        PriceSpotter.Marketplaces.SuppliersFixtures.create()

      assert {:ok, user_suppliers} =
               Marketplaces.create_user_suppliers(user, [
                 %{supplier_id: supplier_id_1, role: :consumer},
                 %{supplier_id: supplier_id_2, role: :maintainer}
               ])

      assert length(user_suppliers) == 2
      assert length(Marketplaces.list_user_suppliers_for_user(user)) == 2
    end

    test "create_user_suppliers/2 rolls back the whole batch when one row is invalid" do
      user = PriceSpotter.AccountsFixtures.user_fixture()
      %{id: supplier_id} = PriceSpotter.Marketplaces.SuppliersFixtures.create()

      assert {:error, 1, %Ecto.Changeset{}} =
               Marketplaces.create_user_suppliers(user, [
                 %{supplier_id: supplier_id, role: :consumer},
                 %{supplier_id: nil, role: :maintainer}
               ])

      assert Marketplaces.list_user_suppliers_for_user(user) == []
    end
  end
end
