defmodule PriceSpotterWeb.Admin.Accounts.UserLive.Show do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _params, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:user, Accounts.get_user!(id))}
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Accounts.UserLive.FormComponent, {:saved, user}},
        socket
      ) do
    {:noreply, assign(socket, :user, user)}
  end

  defp page_title(:show), do: gettext("Show User")
  defp page_title(:edit), do: gettext("Edit User")
end
