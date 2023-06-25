defmodule PriceSpotterWeb.PageControllerTest do
  use PriceSpotterWeb.ConnCase

  import PriceSpotterWeb.Gettext

  setup [:register_and_log_in_user]

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ gettext("Price Spotter")
    assert response =~ gettext("Wholesaler products and prices")

    assert response =~
             gettext(
               "Search, filter and export products and prices from suppliers to your spreadsheets."
             )

    assert response =~ gettext("Products")
  end
end
