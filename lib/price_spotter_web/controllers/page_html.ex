defmodule PriceSpotterWeb.PageHTML do
  use PriceSpotterWeb, :html
  alias Decimal, as: D

  embed_templates "page_html/*"

  def format_money(nil), do: "-"

  def format_money(%D{} = amount) do
    "$#{D.round(amount, 2) |> D.to_string(:normal)}"
  end

  def format_percentage(nil), do: "-"

  def format_percentage(%D{} = percentage) do
    "#{D.round(percentage, 2) |> D.to_string(:normal)}%"
  end
end
