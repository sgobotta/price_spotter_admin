defmodule PriceSpotterWeb.CustomComponents do
  @moduledoc false

  use Phoenix.Component

  attr :has_code, :boolean, required: true
  attr :ean, :string, required: true

  def render_ean(assigns) do
    ~H"""
    <span class={"
        text-sm font-medium md:block text-center self-center bg-gray-100
        rounded-md px-2 shadow-inner-lg border-2 border-gray-200
        #{if @has_code, do: "text-blue-500", else: "text-yellow-500"}
      "}>
      <%= @ean %>
    </span>
    """
  end
end
