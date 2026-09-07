defmodule PriceSpotterWeb.PageController do
  use PriceSpotterWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: gettext("Homepage"))
  end
end
