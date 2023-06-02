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
  end
end
