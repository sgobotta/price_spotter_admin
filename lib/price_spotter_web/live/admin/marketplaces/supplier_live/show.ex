defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.Show do
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
     |> assign(:supplier, Marketplaces.get_supplier!(id))}
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.SupplierLive.FormComponent,
         {:saved, supplier}},
        socket
      ) do
    {:noreply, assign(socket, :supplier, supplier)}
  end

  defp page_title(:show), do: gettext("Show Supplier")
  defp page_title(:edit), do: gettext("Edit Supplier")
end
