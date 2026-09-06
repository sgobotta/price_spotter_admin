defmodule PriceSpotterWeb.Admin.Marketplaces.UserSupplierLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Relations.UserSupplier

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     assign(assign_defaults(session, socket), %{
       users_suppliers: nil,
       meta: nil
     })}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Marketplaces.list_users_suppliers(params) do
      {:ok, {users_suppliers, meta}} ->
        {:noreply,
         socket
         |> assign(users_suppliers: users_suppliers, meta: meta)
         |> assign(filter_fields: filter_fields())
         |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply,
         push_navigate(socket, to: ~p"/admin/marketplaces/users_suppliers")}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/marketplaces/users_suppliers"
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
      Flop.Phoenix.build_path(~p"/admin/marketplaces/users_suppliers", flop,
        backend: assigns.meta.backend
      )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user_supplier = Marketplaces.get_user_supplier!(id)
    {:ok, _} = Marketplaces.delete_user_supplier(user_supplier)

    {:noreply, push_patch(socket, to: ~p"/admin/marketplaces/users_suppliers")}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit User supplier"))
    |> assign(
      :user_supplier,
      Marketplaces.get_user_supplier!(id) |> preload_user_supplier()
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
         {:saved, _user_supplier}},
        socket
      ) do
    {:noreply, socket}
  end

  defp filter_fields do
    [
      role: [
        label: gettext("Role"),
        type: "select",
        prompt: gettext("All roles"),
        options:
          [gettext("Maintainer"), gettext("Consumer")]
          |> Enum.zip([:maintainer, :consumer])
      ]
    ]
  end

  def role_label(:maintainer), do: gettext("Maintainer")
  def role_label(:consumer), do: gettext("Consumer")

  @spec preload_user_supplier(
          PriceSpotter.Marketplaces.Relations.UserSupplier.t()
        ) ::
          PriceSpotter.Marketplaces.Relations.UserSupplier.t()
  defp preload_user_supplier(
         %PriceSpotter.Marketplaces.Relations.UserSupplier{} = us
       ),
       do: PriceSpotter.Repo.preload(us, [:supplier, :user])
end
