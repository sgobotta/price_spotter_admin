defmodule PriceSpotter.Fixtures do
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
  @spec maybe_assign(map(), atom(), module(), module(), atom(), atom()) :: map()
  def maybe_assign(
        attrs,
        attr,
        struct_type,
        fixtures_module,
        action \\ :create,
        related_attr \\ :id
      ) do
    case Map.has_key?(attrs, attr) do
      false ->
        %^struct_type{} = struct = apply(fixtures_module, action, [attrs])
        Map.merge(attrs, %{attr => Map.get(struct, related_attr)})

      true ->
        attrs
    end
  end
end
