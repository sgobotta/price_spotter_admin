defmodule PriceSpotterWeb.CustomComponents do
  @moduledoc false

  use Phoenix.Component

  attr :has_code, :boolean, required: true
  attr :ean, :string, required: true

  def render_ean(assigns) do
    ~H"""
    <span class={"
        text-md font-medium md:block text-center self-center
        #{if @has_code, do: "text-teal-500", else: "text-yellow-500"}
      "}>
      <%= @ean %>
    </span>
    """
  end
end
