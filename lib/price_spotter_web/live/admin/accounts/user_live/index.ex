defmodule PriceSpotterWeb.Admin.Accounts.UserLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts
  alias PriceSpotter.Accounts.User

  @impl true
  def mount(_params, session, socket) do
    {:ok, assign(assign_defaults(session, socket), %{users: nil, meta: nil})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Accounts.list_users(params) do
      {:ok, {users, meta}} ->
        {:noreply,
         socket
         |> assign(users: users, meta: meta)
         |> assign(filter_fields: filter_fields())
         |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply, push_navigate(socket, to: ~p"/admin/accounts/users")}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/accounts/users"
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
      Flop.Phoenix.build_path(~p"/admin/accounts/users", flop,
        backend: assigns.meta.backend
      )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply, push_patch(socket, to: ~p"/admin/accounts/users")}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit User"))
    |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New User"))
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Users"))
    |> assign(:user, nil)
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Accounts.UserLive.FormComponent,
         {:saved, _user}},
        socket
      ) do
    {:noreply, socket}
  end

  defp filter_fields do
    [
      email: [
        label: gettext("Email"),
        op: :ilike,
        placeholder: gettext("Filter by email")
      ],
      role: [
        label: gettext("Role"),
        type: "select",
        prompt: gettext("All roles"),
        options:
          [gettext("User"), gettext("Admin")] |> Enum.zip([:user, :admin])
      ]
    ]
  end

  def role_label(:user), do: gettext("User")
  def role_label(:admin), do: gettext("Admin")
end
