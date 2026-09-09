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

  test "GET / renders the access-scoped 24h summary metric cards", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ gettext("24h summary scoped by your customer access")
    assert response =~ gettext("Total products")
    assert response =~ gettext("Scraped in 24h")
    assert response =~ gettext("Price increases")
    assert response =~ gettext("Price decreases")
    assert response =~ gettext("Top increase product")
    assert response =~ gettext("Top decrease product")

    # A freshly registered user has no snapshots in scope, so movement cards
    # fall back to their explicit empty states.
    assert response =~ gettext("No price increases in the last 24h.")
    assert response =~ gettext("No price decreases in the last 24h.")
  end
end
