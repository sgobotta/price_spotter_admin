defmodule PriceSpotterWeb.PageController do
  use PriceSpotterWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false, page_title: gettext("Homepage"))
  end
end
