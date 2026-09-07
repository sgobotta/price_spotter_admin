defmodule PriceSpotterWeb.Admin.ExpandableList do
  @moduledoc false

  def new, do: MapSet.new()

  def expanded?(expanded, key), do: MapSet.member?(expanded, key)

  def toggle(expanded, key) do
    if expanded?(expanded, key) do
      MapSet.delete(expanded, key)
    else
      MapSet.put(expanded, key)
    end
  end
end
