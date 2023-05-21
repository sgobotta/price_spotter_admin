defmodule PriceSpotter.MarketplacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """

  @doc """
  Generate a product.
  """
  def product_fixture(attrs \\ %{}) do
    {:ok, product} =
      attrs
      |> Enum.into(%{
        category: "some category",
        img_url: "some img_url",
        internal_id: "some internal_id",
        name: "some name",
        price: "120.5",
        supplier_name: "some supplier_name",
        supplier_url: "some supplier_url"
      })
      |> PriceSpotter.Marketplaces.create_product()

    product
  end
end
