defmodule PriceSpotter.MarketplacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """

  alias PriceSpotter.Marketplaces.Supplier
  alias PriceSpotter.Marketplaces.SuppliersFixtures

  import PriceSpotter.Fixtures

  @valid_attrs %{
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
    price: "241.0",
    supplier_name: "some updated supplier_name",
    supplier_url: "some updated supplier_url"
  }

  def valid_attrs(attrs \\ %{}), do: Enum.into(attrs, @valid_attrs)
  def update_attrs(attrs \\ %{}), do: Enum.into(attrs, @update_attrs)

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> maybe_assign_supplier()
      |> Enum.into(@valid_attrs)
      |> PriceSpotter.Marketplaces.create_product()

    product
  end

  @doc """
  Convenience function to assign #{Supplier} attributes through the
  #{SuppliersFixtures} module.
  """
  @spec maybe_assign_supplier(map()) :: map()
  def maybe_assign_supplier(attrs),
    do: maybe_assign(attrs, :supplier_id, Supplier, SuppliersFixtures)

  @doc """
  Generate a user_supplier.
  """
  def user_supplier_fixture(attrs \\ %{}) do
    {:ok, user_supplier} =
      attrs
      |> Enum.into(%{
        role: :maintainer
      })
      |> PriceSpotter.Marketplaces.create_user_supplier()

    user_supplier
  end
end
