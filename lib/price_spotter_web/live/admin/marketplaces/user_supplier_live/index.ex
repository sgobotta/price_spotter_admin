defmodule PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Relations.UserSupplier

  @impl true
  def mount(_params, _session, socket) do
    users_suppliers =
      Marketplaces.list_users_suppliers()
      |> Enum.map(&preload_user_supplier(&1))

    {:ok, stream(socket, :users_suppliers, users_suppliers)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit User supplier"))
    |> assign(
      :user_supplier,
      Marketplaces.get_user_supplier!(id) |> preload_user_supplier
    )
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New User supplier"))
    |> assign(:user_supplier, %UserSupplier{} |> preload_user_supplier())
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Listing Users suppliers"))
    |> assign(:user_supplier, nil)
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.FormComponent,
         {:saved, user_supplier}},
        socket
      ) do
    {:noreply,
     stream_insert(
       socket,
       :users_suppliers,
       preload_user_supplier(user_supplier)
     )}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user_supplier = Marketplaces.get_user_supplier!(id)
    {:ok, _} = Marketplaces.delete_user_supplier(user_supplier)

    {:noreply, stream_delete(socket, :users_suppliers, user_supplier)}
  end

  @spec preload_user_supplier(
          PriceSpotter.Marketplaces.Relations.UserSupplier.t()
        ) ::
          PriceSpotter.Marketplaces.Relations.UserSupplier.t()
  defp preload_user_supplier(
         %PriceSpotter.Marketplaces.Relations.UserSupplier{} = us
       ),
       do: PriceSpotter.Repo.preload(us, [:supplier, :user])
end
