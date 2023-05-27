defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Show do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:product, Marketplaces.get_product!(id))}
  end

  @impl true
  def handle_info({PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent, {:saved, _product}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Marketplaces.delete_product(socket.assigns.product)

    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
  end

  defp page_title(:show), do: gettext("Show Product")
  defp page_title(:edit), do: gettext("Edit Product")
end
