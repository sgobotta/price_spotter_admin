defmodule PriceSpotterWeb.Admin.Marketplaces.SupplierLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts
  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Supplier
  alias PriceSpotterWeb.Admin.ExpandableList

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(assign_defaults(session, socket), %{
       suppliers: nil,
       meta: nil,
       expanded: ExpandableList.new()
     })}
  end

  @impl true
  def handle_params(params, _url, socket) do
    user = socket.assigns.current_user

    case Marketplaces.list_suppliers_for_user(params, user) do
      {:ok, {suppliers, meta}} ->
        {:noreply,
         socket
         |> assign(suppliers: suppliers, meta: meta)
         |> assign(
           :has_granted_suppliers,
           Marketplaces.user_has_suppliers?(user)
         )
         |> assign(filter_fields: filter_fields())
         |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/suppliers")}
    end
  end

  @impl true
  def handle_event("toggle_expand", %{"key" => key}, socket) do
    expanded = ExpandableList.toggle(socket.assigns.expanded, key)
    {:noreply, assign(socket, :expanded, expanded)}
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
    user = socket.assigns.current_user

    case Marketplaces.get_supplier_for_user(id, user) do
      nil ->
        {:noreply, unauthorized_delete(socket)}

      supplier ->
        case Marketplaces.delete_supplier_for_user(supplier, user) do
          {:ok, _} ->
            {:noreply,
             push_patch(socket, to: ~p"/admin/marketplaces/suppliers")}

          {:error, :unauthorized} ->
            {:noreply, unauthorized_delete(socket)}
        end
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Supplier"))
    |> assign(
      :supplier,
      Marketplaces.get_supplier_for_user!(id, socket.assigns.current_user)
    )
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

  defp unauthorized_delete(socket) do
    put_flash(
      socket,
      :error,
      gettext("You are not allowed to delete suppliers")
    )
  end

  defp empty_suppliers_label(true), do: gettext("No suppliers found.")

  defp empty_suppliers_label(false),
    do: gettext("You don't have access to any suppliers.")

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
