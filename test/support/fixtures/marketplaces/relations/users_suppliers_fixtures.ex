defmodule PriceSpotter.Marketplaces.Relations.UsersSuppliersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PriceSpotter.Marketplaces` context.
  """
  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Relations.UserSupplier

  import PriceSpotter.Fixtures

  @valid_attrs %{role: :consumer}
  @update_attrs %{role: :maintainer}
  @invalid_attrs %{role: nil}

  def valid_attrs(attrs \\ %{}), do: attrs |> Enum.into(@valid_attrs)
  def update_attrs(attrs \\ %{}), do: attrs |> Enum.into(@update_attrs)
  def invalid_attrs(attrs \\ %{}), do: attrs |> Enum.into(@invalid_attrs)

  def create(attrs \\ %{}) do
    {:ok, %UserSupplier{} = shop} =
      attrs
      |> maybe_assign_user()
      |> maybe_assign_supplier()
      |> Enum.into(valid_attrs())
      |> Marketplaces.create_user_supplier()

    shop
  end

  @doc """
  Convenience function to assign #{PriceSpotter.Accounts.User} attributes
  through the #{PriceSpotter.AccountsFixtures} module.
  """
  @spec maybe_assign_user(map()) :: map()
  def maybe_assign_user(attrs),
    do:
      maybe_assign(
        attrs,
        :user_id,
        PriceSpotter.Accounts.User,
        PriceSpotter.AccountsFixtures,
        :user_fixture
      )

  @doc """
  Convenience function to assign #{Supplier} attributes through the
  #{SuppliersFixtures} module.
  """
  @spec maybe_assign_supplier(map()) :: map()
  def maybe_assign_supplier(attrs),
    do:
      maybe_assign(
        attrs,
        :supplier_id,
        PriceSpotter.Marketplaces.Supplier,
        PriceSpotter.Marketplaces.SuppliersFixtures
      )
end
