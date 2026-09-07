defmodule PriceSpotterWeb.Admin.Extractor.SpiderLiveTest do
  use PriceSpotterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PriceSpotterWeb.Gettext

  alias PriceSpotter.Extractor.FakeHttpAdapter

  setup do
    on_exit(fn ->
      Application.delete_env(:price_spotter, :extractor_test_stub)
    end)

    :ok
  end

  defp spider_json(attrs) do
    Map.merge(
      %{
        "id" => "1",
        "name" => "coto-by-ean",
        "cron" => "*/5 * * * *",
        "active" => true,
        "next_run_time" => "2026-09-06T18:45:00-03:00",
        "supports_dry_run" => true,
        "supports_ean_override" => true
      },
      attrs
    )
  end

  defp stub_list(spiders) do
    FakeHttpAdapter.stub(fn :get, _url, _headers, nil -> {:ok, 200, spiders} end)
  end

  describe "as an admin" do
    setup [:register_and_log_in_admin]

    test "lists spiders with their schedule and active state", %{conn: conn} do
      stub_list([spider_json(%{})])

      {:ok, _view, html} = live(conn, ~p"/admin/extractor/spiders")

      assert html =~ "coto-by-ean"
      assert html =~ "Every 5 minutes"
      assert html =~ gettext("Active")
    end

    test "hides the dry run button for spiders that don't support it", %{
      conn: conn
    } do
      stub_list([
        spider_json(%{"name" => "yaguar", "supports_dry_run" => false})
      ])

      {:ok, _view, html} = live(conn, ~p"/admin/extractor/spiders")

      refute html =~ "spiders-yaguar-dry-run"
      assert html =~ "spiders-yaguar-run"
    end

    test "toggles active via the extractor API", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, body ->
        assert Jason.decode!(body) == %{"active" => false}
        {:ok, 200, spider_json(%{"active" => false})}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-toggle")
        |> render_click()

      assert html =~ gettext("Inactive")
    end

    test "saves an edited cron expression", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, body ->
        assert Jason.decode!(body) == %{"cron" => "0 * * * *"}
        {:ok, 200, spider_json(%{"cron" => "0 * * * *"})}
      end)

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "0 * * * *"})
        |> render_submit()

      assert html =~ "Every hour"
    end

    test "flashes the extractor's error message on a failed schedule update", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        {:ok, 400, %{"error" => "cron does not parse"}}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-toggle")
        |> render_click()

      assert html =~ "cron does not parse"
    end
  end

  describe "as a non-admin user" do
    setup [:register_and_log_in_user]

    test "redirects away", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/admin/extractor/spiders")
    end
  end
end
