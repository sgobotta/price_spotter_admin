defmodule PriceSpotter.Marketplaces.SuppliersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """

  @valid_attrs %{
    name: "some name"
  }

  @update_attrs %{
    name: "some updated name"
  }

  @invalid_attrs %{
    name: nil
  }

  def unique_name, do: "name#{System.unique_integer()}"

  def valid_attrs(attrs \\ %{}),
    do: Enum.into(attrs, Enum.into(%{name: unique_name()}, @valid_attrs))

  def update_attrs(attrs \\ %{}), do: Enum.into(attrs, @update_attrs)
  def invalid_attrs(attrs \\ %{}), do: Enum.into(attrs, @invalid_attrs)

  @doc """
  Generate a supplier.
  """
  def create(attrs \\ %{}) do
    {:ok, supplier} =
      attrs
      |> Enum.into(valid_attrs(attrs))
      |> PriceSpotter.Marketplaces.create_supplier()

    supplier
  end
end
