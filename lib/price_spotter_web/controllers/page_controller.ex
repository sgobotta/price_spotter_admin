defmodule PriceSpotterWeb.PageController do
  use PriceSpotterWeb, :controller

  alias PriceSpotter.Marketplaces

  def home(conn, _params) do
    metrics =
      case conn.assigns[:current_user] do
        nil -> nil
        user -> Marketplaces.get_homepage_metrics(user)
      end

    render(conn, :home, page_title: gettext("Homepage"), metrics: metrics)
  end
end
