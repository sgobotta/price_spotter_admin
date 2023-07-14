defmodule PriceSpotterWeb.Admin.Accounts.UserLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts
  alias PriceSpotter.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :users, Accounts.list_users())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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
  def handle_info({PriceSpotterWeb.Admin.Accounts.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply, stream_delete(socket, :users, user)}
  end
end
