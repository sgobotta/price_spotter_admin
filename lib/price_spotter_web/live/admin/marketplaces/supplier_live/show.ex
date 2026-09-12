defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.Show do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts
  alias PriceSpotter.Marketplaces

  @impl true
  def mount(_params, session, socket) do
    {:ok, assign_defaults(session, socket)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    supplier = Marketplaces.get_supplier!(id)
    user = socket.assigns.current_user

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:supplier, supplier)
     |> assign(
       :subscribed?,
       Marketplaces.subscribed_to_supplier?(user, supplier.id)
     )}
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
