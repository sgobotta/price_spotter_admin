defmodule PriceSpotter.Flop.Helpers do
  @moduledoc """
  Shared helpers for querying with `Flop` under cursor pagination.
  """

  @doc """
  Ensures `flop.order_by` includes `tiebreaker`, appending it if missing.

  Flop's cursor pagination requires the `ORDER BY` fields to be unique
  across the result set. None of this app's schemas expose a naturally
  unique sortable field, so every list query appends a stable tiebreaker
  (the primary key by default) to whatever order the user picked.
  """
  @spec ensure_unique_order(Flop.t(), atom()) :: Flop.t()
  def ensure_unique_order(
        %Flop{order_by: order_by, order_directions: dirs} = flop,
        tiebreaker \\ :id
      ) do
    order_by = order_by || []

    if tiebreaker in order_by do
      flop
    else
      %{
        flop
        | order_by: order_by ++ [tiebreaker],
          order_directions: (dirs || []) ++ [:asc]
      }
    end
  end
end
