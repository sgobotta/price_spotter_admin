defmodule PriceSpotter.MarketplacesTest do
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

      assert {:ok, %Product{} = product} = Marketplaces.create_product(valid_attrs)
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
      assert {:error, %Ecto.Changeset{}} = Marketplaces.create_product(@invalid_attrs)
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

      assert {:ok, %Product{} = product} = Marketplaces.update_product(product, update_attrs)
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
      assert {:error, %Ecto.Changeset{}} = Marketplaces.update_product(product, @invalid_attrs)
      assert product == Marketplaces.get_product!(product.id)
    end

    test "delete_product/1 deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Marketplaces.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Marketplaces.get_product!(product.id) end
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
    end
  end

  describe "suppliers" do
    alias PriceSpotter.Marketplaces.Supplier

    import PriceSpotter.MarketplacesFixtures

    @invalid_attrs %{name: nil}

    test "list_suppliers/0 returns all suppliers" do
      supplier = supplier_fixture()
      assert Marketplaces.list_suppliers() == [supplier]
    end

    test "get_supplier!/1 returns the supplier with given id" do
      supplier = supplier_fixture()
      assert Marketplaces.get_supplier!(supplier.id) == supplier
    end

    test "create_supplier/1 with valid data creates a supplier" do
      valid_attrs = %{name: "some name"}

      assert {:ok, %Supplier{} = supplier} = Marketplaces.create_supplier(valid_attrs)
      assert supplier.name == "some name"
    end

    test "create_supplier/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Marketplaces.create_supplier(@invalid_attrs)
    end

    test "update_supplier/2 with valid data updates the supplier" do
      supplier = supplier_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Supplier{} = supplier} = Marketplaces.update_supplier(supplier, update_attrs)
      assert supplier.name == "some updated name"
    end

    test "update_supplier/2 with invalid data returns error changeset" do
      supplier = supplier_fixture()
      assert {:error, %Ecto.Changeset{}} = Marketplaces.update_supplier(supplier, @invalid_attrs)
      assert supplier == Marketplaces.get_supplier!(supplier.id)
    end

    test "delete_supplier/1 deletes the supplier" do
      supplier = supplier_fixture()
      assert {:ok, %Supplier{}} = Marketplaces.delete_supplier(supplier)
      assert_raise Ecto.NoResultsError, fn -> Marketplaces.get_supplier!(supplier.id) end
    end

    test "change_supplier/1 returns a supplier changeset" do
      supplier = supplier_fixture()
      assert %Ecto.Changeset{} = Marketplaces.change_supplier(supplier)
    end
  end
end
