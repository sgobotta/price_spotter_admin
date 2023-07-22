defmodule PriceSpotter.MarketplacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """

  alias PriceSpotter.Marketplaces.Supplier
  alias PriceSpotter.Marketplaces.SuppliersFixtures

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
  Convenience function to assigning attributes for fixture creation. Whenever
  the desired attribute does not exist, a new fixture is created in order to
  satisfy the needed relationship.

  ## Examples:

      iex> maybe_assign(%{shop_id: "some id"}, :shop_id, Shop, ShopFixtures)
      %{shop_id: "some id"}

      iex> maybe_assign(%{}, :shop_id, Shop, ShopFixtures)
      %{shop_id: "some new id"}

  """
  @spec maybe_assign(map(), atom(), module(), module(), atom()) :: map()
  def maybe_assign(attrs, attr, struct_type, fixtures_module, action \\ :create) do
    case Map.has_key?(attrs, attr) do
      false ->
        %^struct_type{id: id} = apply(fixtures_module, action, [attrs])
        Map.merge(attrs, %{attr => id})

      true ->
        attrs
    end
  end
end
