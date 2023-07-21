defmodule PriceSpotter.MarketplacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """

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
      |> Enum.into(@valid_attrs)
      |> PriceSpotter.Marketplaces.create_product()

    product
  end
end
