defmodule PriceSpotterWeb.LiveHelpers do
  # import Phoenix.LiveView
  # import PriceSpotterWeb.Gettext
  import Phoenix.Component, only: [assign_new: 3]

  alias PriceSpotter.Accounts
  alias PriceSpotter.Accounts.User
  # alias PriceSpotterWeb.Router.Helpers, as: Routes
  alias PriceSpotterWeb.UserAuth

  @doc """
  Given a session and a socket, subscribes to the user auth topic and assigns
  the current user to return a new socket.
  """
  def assign_defaults(session, socket) do
    :ok = subscribe_user_auth()

    socket
    |> assign_user(session)
  end

  defp subscribe_user_auth,
    do: PriceSpotterWeb.Endpoint.subscribe(UserAuth.pubsub_topic())

  defp assign_user(socket, session) do
    assign_new(socket, :current_user, fn ->
      find_current_user(session)
    end)
  end

  defp find_current_user(%{"user_token" => nil} = _session), do: nil

  defp find_current_user(%{"user_token" => user_token} = _session) do
    with user_token when not is_nil(user_token) <- user_token,
         %User{} = user <- Accounts.get_user_by_session_token(user_token),
         do: user
  end

  defp find_current_user(_session), do: nil
end
