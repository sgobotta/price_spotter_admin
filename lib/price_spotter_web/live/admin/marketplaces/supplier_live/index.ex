defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Supplier

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :suppliers, Marketplaces.list_suppliers())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Supplier"))
    |> assign(:supplier, Marketplaces.get_supplier!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Supplier"))
    |> assign(:supplier, %Supplier{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Listing Suppliers"))
    |> assign(:supplier, nil)
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.SupplierLive.FormComponent,
         {:saved, supplier}},
        socket
      ) do
    {:noreply, stream_insert(socket, :suppliers, supplier)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    supplier = Marketplaces.get_supplier!(id)
    {:ok, _} = Marketplaces.delete_supplier(supplier)

    {:noreply, stream_delete(socket, :suppliers, supplier)}
  end
end
