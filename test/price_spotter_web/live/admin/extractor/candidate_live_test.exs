defmodule PriceSpotterWeb.Admin.Extractor.CandidateLiveTest do
  use PriceSpotterWeb.ConnCase

  import Phoenix.LiveViewTest
  import PriceSpotter.MarketplacesFixtures
  import PriceSpotterWeb.Gettext

  alias PriceSpotter.Extractor
  alias PriceSpotter.Marketplaces

  defp candidate_attrs(product, overrides \\ []) do
    candidate =
      Enum.into(overrides, %{
        "ean_candidate" => "7790070418161",
        "name" => "Yerba Mate 1kg Coto",
        "supplier" => "coto",
        "url" => "https://coto.example/p/1",
        "image_url" => "https://coto.example/img/1.png",
        "price" => "1200.50",
        "last_fetched_at" => "2026-09-08T05:00:00Z"
      })

    %{
      "product_id" => product.id,
      "product_name" => product.name,
      "category" => product.category,
      "candidates" => [candidate]
    }
  end

  defp create_pending_set(_context) do
    product = product_fixture(%{name: "Yerba Mate 1kg", category: "yerbas"})
    {:ok, set} = Extractor.upsert_candidate_set(candidate_attrs(product))
    %{product: product, set: set}
  end

  describe "Index (admin)" do
    setup [:create_pending_set, :register_and_log_in_admin]

    test "lists pending candidate sets", %{conn: conn, set: set} do
      {:ok, _live, html} = live(conn, ~p"/admin/extractor/candidates")

      assert html =~ gettext("Match candidates")
      assert html =~ "Yerba Mate 1kg"
      assert html =~ "candidate-sets-#{set.id}"
    end

    test "filters by supplier", %{conn: conn} do
      other =
        product_fixture(%{
          name: "Cafe La Virginia",
          category: "cafes",
          internal_id: "cafe-la-virginia"
        })

      {:ok, _} =
        Extractor.upsert_candidate_set(
          candidate_attrs(other, [
            {"ean_candidate", "7891000389300"},
            {"name", "Cafe La Virginia"},
            {"supplier", "jumbo"}
          ])
        )

      {:ok, live, _html} = live(conn, ~p"/admin/extractor/candidates")

      html =
        render_change(element(live, "#candidate-filters"), %{
          "supplier" => "coto"
        })

      assert html =~ "Yerba Mate 1kg"
      refute html =~ "Cafe La Virginia"
    end

    test "clear filters restores the full list", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/admin/extractor/candidates")

      render_change(element(live, "#candidate-filters"), %{"name" => "nomatch"})
      refute render(live) =~ "Yerba Mate 1kg"

      html =
        live
        |> element("#clear-filters")
        |> render_click()

      assert html =~ "Yerba Mate 1kg"
    end

    test "approving a candidate applies the EAN and removes the set", %{
      conn: conn,
      set: set,
      product: product
    } do
      {:ok, live, _html} = live(conn, ~p"/admin/extractor/candidates")

      live
      |> element("#candidate-sets-#{set.id}-header")
      |> render_click()

      live
      |> element("#approve-#{hd(set.candidates).id}")
      |> render_click()

      html =
        live
        |> element("#confirm-decision")
        |> render_click()

      refute html =~ "candidate-sets-#{set.id}"
      assert Extractor.list_pending_candidate_sets() == []
      assert Marketplaces.get_product!(product.id).ean == "7790070418161"
    end

    test "disapproving a candidate removes the set without touching the product",
         %{conn: conn, set: set, product: product} do
      {:ok, live, _html} = live(conn, ~p"/admin/extractor/candidates")

      live
      |> element("#candidate-sets-#{set.id}-header")
      |> render_click()

      live
      |> element("#disapprove-#{hd(set.candidates).id}")
      |> render_click()

      live
      |> element("#confirm-decision")
      |> render_click()

      assert Extractor.list_pending_candidate_sets() == []
      refute Marketplaces.get_product!(product.id).ean == "7790070418161"
    end

    test "does not render a non-http scheme as a source link or image", %{
      conn: conn,
      set: safe_set
    } do
      unsafe =
        product_fixture(%{
          name: "Unsafe Source Product",
          category: "yerbas",
          internal_id: "unsafe-source"
        })

      {:ok, unsafe_set} =
        Extractor.upsert_candidate_set(
          candidate_attrs(unsafe, [
            {"ean_candidate", "7891000389300"},
            {"name", "Unsafe Source Product"},
            {"url", "javascript:alert(document.cookie)"},
            {"image_url", "javascript:alert(1)"}
          ])
        )

      {:ok, live, _html} = live(conn, ~p"/admin/extractor/candidates")

      # Expanding the unsafe set reveals its evidence, but the javascript:
      # url/image must be dropped rather than rendered as an href/src.
      unsafe_html =
        live
        |> element("#candidate-sets-#{unsafe_set.id}-header")
        |> render_click()

      assert unsafe_html =~ "Unsafe Source Product"
      refute unsafe_html =~ "javascript:"

      # The safe https fixture link still renders once its row is expanded.
      safe_html =
        live
        |> element("#candidate-sets-#{safe_set.id}-header")
        |> render_click()

      assert safe_html =~ "https://coto.example/p/1"
    end
  end

  describe "Index (admin, empty)" do
    setup [:register_and_log_in_admin]

    test "shows an empty state when there is nothing to review", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/admin/extractor/candidates")

      assert html =~ gettext("No pending match candidates.")
    end
  end

  describe "Index (non-admin)" do
    setup [:create_pending_set, :register_and_log_in_user]

    test "cannot access the review page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/extractor/candidates")
    end
  end
end
