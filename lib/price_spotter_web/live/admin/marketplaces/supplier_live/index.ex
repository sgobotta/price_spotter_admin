defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Supplier

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(assign_defaults(session, socket), %{suppliers: nil, meta: nil})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Marketplaces.list_suppliers(params) do
      {:ok, {suppliers, meta}} ->
        {:noreply,
         socket
         |> assign(suppliers: suppliers, meta: meta)
         |> assign(filter_fields: filter_fields())
         |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/suppliers")}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/marketplaces/suppliers"
         |> URI.parse()
         |> Map.put(:query, Plug.Conn.Query.encode(params))
         |> URI.to_string()
     )}
  end

  @impl true
  def handle_event("reset-filter", _params, %{assigns: assigns} = socket) do
    flop =
      assigns.meta.flop
      |> Flop.reset_filters()
      |> Map.merge(%{after: nil, before: nil})

    path =
      Flop.Phoenix.build_path(~p"/admin/marketplaces/suppliers", flop,
        backend: assigns.meta.backend
      )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    supplier = Marketplaces.get_supplier!(id)
    {:ok, _} = Marketplaces.delete_supplier(supplier)

    {:noreply, push_patch(socket, to: ~p"/admin/marketplaces/suppliers")}
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
         {:saved, _supplier}},
        socket
      ) do
    {:noreply, socket}
  end

  defp filter_fields do
    [
      name: [
        label: gettext("Name"),
        op: :ilike,
        placeholder: gettext("Filter by name")
      ]
    ]
  end
end
