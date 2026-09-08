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

  defp expand(view, key) do
    view
    |> element("#spiders-#{key}-toggle-expand")
    |> render_click()
  end

  defp expanded?(view, key) do
    view
    |> element("#spiders-#{key}-expand")
    |> render()
    |> String.contains?("grid-rows-[1fr]")
  end

  describe "as an admin" do
    setup [:register_and_log_in_admin]

    test "lists spiders with their schedule and active state", %{conn: conn} do
      stub_list([spider_json(%{})])

      {:ok, view, html} = live(conn, ~p"/admin/extractor/spiders")

      assert html =~ "coto-by-ean"
      assert html =~ "Every 5 minutes"
      refute expanded?(view, "coto-by-ean")
    end

    test "expands a row to reveal the schedule form, active toggle and run controls",
         %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")

      refute expanded?(view, "coto-by-ean")

      html = expand(view, "coto-by-ean")

      assert expanded?(view, "coto-by-ean")
      assert html =~ "spiders-coto-by-ean-cron-form"
      assert html =~ "spiders-coto-by-ean-toggle"
      assert html =~ "spiders-coto-by-ean-run"
      assert html =~ "hero-chevron-up-solid"
    end

    test "collapses an expanded row again", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")

      expand(view, "coto-by-ean")
      html = expand(view, "coto-by-ean")

      refute expanded?(view, "coto-by-ean")
      assert html =~ "hero-chevron-down-solid"
    end

    test "hides the dry run button for spiders that don't support it", %{
      conn: conn
    } do
      stub_list([
        spider_json(%{"name" => "yaguar", "supports_dry_run" => false})
      ])

      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "yaguar")

      refute html =~ "spiders-yaguar-dry-run"
      assert html =~ "spiders-yaguar-run"
    end

    test "hides the eans field for spiders that don't support an override", %{
      conn: conn
    } do
      stub_list([
        spider_json(%{"name" => "yaguar", "supports_ean_override" => false})
      ])

      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "yaguar")

      refute html =~ ~s(name="eans")
    end

    test "toggles active via the extractor API", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

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
      expand(view, "coto-by-ean")

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
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        {:ok, 400, %{"error" => "cron does not parse"}}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-toggle")
        |> render_click()

      assert html =~ "cron does not parse"
    end

    test "triggers a dry run with a newline-separated list of eans", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :post, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/run")

        assert Jason.decode!(body) == %{
                 "dry_run" => true,
                 "eans" => ["7790070418161", "7790742307279"]
               }

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      view
      |> form("#spiders-coto-by-ean-eans-form", %{
        "eans" => "7790070418161\n7790742307279"
      })
      |> render_change()

      html =
        view
        |> element("#spiders-coto-by-ean-dry-run")
        |> render_click()

      assert html =~ gettext("Dry run")
      assert html =~ "2 EANs"
    end

    test "triggers a plain run with no eans when the field is left blank", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
        assert Jason.decode!(body) == %{"dry_run" => false}

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-run")
        |> render_click()

      assert html =~ gettext("Run")
    end

    test "keeps the run log inside the row, visible only while it is expanded",
         %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-run")
        |> render_click()

      assert html =~ "spiders-coto-by-ean-active-run"
      assert expanded?(view, "coto-by-ean")

      html = expand(view, "coto-by-ean")

      refute html =~ "spiders-coto-by-ean-active-run"
      refute expanded?(view, "coto-by-ean")

      html = expand(view, "coto-by-ean")
      assert html =~ "spiders-coto-by-ean-active-run"
      assert expanded?(view, "coto-by-ean")
    end

    test "shows a stop button only while the run is active", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "coto-by-ean")

      refute html =~ "spiders-coto-by-ean-stop-run"

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-run")
        |> render_click()

      assert html =~ "spiders-coto-by-ean-stop-run"
      assert html =~ gettext("Running")
    end

    test "requests to stop a running extractor and shows stopping feedback", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      view
      |> element("#spiders-coto-by-ean-run")
      |> render_click()

      FakeHttpAdapter.stub(fn :post, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/runs/run-1/stop")
        assert Jason.decode!(body) == %{}
        {:ok, 202, %{"status" => "stopping"}}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-stop-run")
        |> render_click()

      assert html =~
               gettext(
                 "Stop requested. Waiting for the extractor to finish the run."
               )

      assert html =~ gettext("Stopping")
    end

    test "shows extractor error when stop request fails", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      view
      |> element("#spiders-coto-by-ean-run")
      |> render_click()

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 400, %{"error" => "run is not stoppable"}}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-stop-run")
        |> render_click()

      assert html =~ "run is not stoppable"
      assert html =~ gettext("Running")
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
