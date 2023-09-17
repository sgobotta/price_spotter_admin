defmodule PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.Show do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:user_supplier, Marketplaces.get_user_supplier!(id))}
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.FormComponent,
         {:saved, supplier}},
        socket
      ) do
    {:noreply, assign(socket, :supplier, supplier)}
  end

  defp page_title(:show), do: gettext("Show User supplier")
  defp page_title(:edit), do: gettext("Edit User supplier")
end
