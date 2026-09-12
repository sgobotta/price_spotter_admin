defmodule PriceSpotterWeb.Admin.Extractor.SpiderLiveTest do
  use PriceSpotterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import PriceSpotterWeb.Gettext

  alias Decimal, as: D
  alias PriceSpotter.Extractor.FakeHttpAdapter
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotter.Repo

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
        "type" => "by_ean",
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

  defp submit_eans(view, key, eans) do
    view
    |> form("#spiders-#{key}-eans-form", %{"eans" => eans})
    |> render_change()

    view
    |> element("#spiders-#{key}-save-eans")
    |> render_click()
  end

  defp confirm_save_eans(view) do
    view
    |> element("#confirm-save-eans")
    |> render_click()
  end

  defp confirm_toggle_active(view) do
    view
    |> element("#confirm-toggle-active")
    |> render_click()
  end

  defp confirm_save_cron(view) do
    view
    |> element("#confirm-save-cron")
    |> render_click()
  end

  defp runtime_params_json(overrides \\ %{}) do
    Map.merge(
      %{
        "match_timeout_ms" => %{
          "type" => "int",
          "default" => 2000,
          "value" => 2000,
          "description" => "Wait for a product tile."
        },
        "debounce_ms" => %{
          "type" => "int",
          "default" => 1000,
          "value" => 1000,
          "description" => "Sleep after fill()."
        }
      },
      overrides
    )
  end

  defp spider_with_params(attrs \\ %{}) do
    spider_json(Map.merge(%{"runtime_params" => runtime_params_json()}, attrs))
  end

  defp confirm_reset_params(view) do
    view
    |> element("#confirm-reset-params")
    |> render_click()
  end

  describe "as an admin" do
    setup [:register_and_log_in_admin]

    setup do
      Repo.insert!(%Product{
        ean: "7790070418161",
        category: "beverages",
        img_url: "https://example.com/1.jpg",
        internal_id: "known-1",
        supplier_name: "coto",
        name: "Known Product 1",
        price: D.new("1.0")
      })

      Repo.insert!(%Product{
        ean: "7790742307279",
        category: "beverages",
        img_url: "https://example.com/2.jpg",
        internal_id: "known-2",
        supplier_name: "coto",
        name: "Known Product 2",
        price: D.new("2.0")
      })

      :ok
    end

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
      assert html =~ gettext("Schedule")
      assert html =~ gettext("Cron expression")
      assert html =~ gettext("EAN codes")
      assert html =~ gettext("Click to deactivate")
      assert html =~ "hero-chevron-up-solid"
    end

    test "toggles the activate tooltip when the spider is inactive", %{
      conn: conn
    } do
      stub_list([spider_json(%{"active" => false})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "coto-by-ean")

      assert html =~ gettext("Click to activate")

      html =
        view
        |> element("#spiders-coto-by-ean-toggle")
        |> render_click()

      assert html =~ gettext("Activate extractor")

      assert html =~
               gettext("You are about to activate %{name}.", name: "coto-by-ean")
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

    test "shows the eans field when the extractor omits type", %{conn: conn} do
      stub_list([Map.delete(spider_json(%{}), "type")])

      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "coto-by-ean")

      assert html =~ ~s(id="spiders-coto-by-ean-eans-form")
    end

    test "hides the eans field for spiders that don't support an override", %{
      conn: conn
    } do
      stub_list([
        spider_json(%{
          "name" => "yaguar",
          "type" => "by_keyword",
          "supports_ean_override" => false
        })
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

      assert html =~ "toggle-active-modal"
      assert html =~ gettext("Deactivate extractor")

      assert html =~
               gettext("You are about to deactivate %{name}.",
                 name: "coto-by-ean"
               )

      html = confirm_toggle_active(view)
      assert html =~ gettext("Inactive")
    end

    test "does not toggle active when the confirmation modal is closed", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        flunk("closing the toggle modal should not call the extractor API")
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-toggle")
        |> render_click()

      assert html =~ "toggle-active-modal"
      refute html =~ gettext("Inactive")

      html = render_click(view, "cancel_toggle_active")

      refute html =~ "toggle-active-modal"
      assert html =~ gettext("Active")
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

      assert html =~ "save-cron-modal"
      assert html =~ "Every hour"
      assert html =~ "Every 5 minutes"
      refute html =~ gettext("Schedule saved successfully.")

      html = confirm_save_cron(view)
      assert html =~ "Every hour"
      assert html =~ gettext("Schedule saved successfully.")
    end

    test "does not save the cron expression when the confirmation modal is closed",
         %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        flunk("closing the cron modal should not call the extractor API")
      end)

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "0 * * * *"})
        |> render_submit()

      assert html =~ "save-cron-modal"
      refute html =~ gettext("Schedule saved successfully.")

      html = render_click(view, "cancel_save_cron")

      refute html =~ "save-cron-modal"
      refute html =~ "Every hour"
      assert html =~ "Every 5 minutes"
      assert html =~ ~s(value="*/5 * * * *")
      refute html =~ gettext("Schedule saved successfully.")
    end

    test "shows a live preview while editing the cron expression", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "0 9 * * 1"})
        |> render_change()

      assert html =~ "At 09:00, only on Monday"
      assert html =~ "Every 5 minutes"
    end

    test "gently warns when the cron preview is invalid", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "not a cron"})
        |> render_change()

      assert html =~
               gettext(
                 "We couldn't read that schedule yet. Please check the cron format."
               )
    end

    test "does not attempt to save an invalid cron expression", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        flunk("invalid cron submissions should not call the extractor API")
      end)

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "not a cron"})
        |> render_submit()

      assert html =~
               gettext(
                 "We couldn't read that schedule yet. Please check the cron format."
               )
    end

    test "keeps the attempted cron value in the input after an invalid submit",
         %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        flunk("invalid cron submissions should not call the extractor API")
      end)

      html =
        view
        |> form("#spiders-coto-by-ean-cron-form", %{"cron" => "not a cron"})
        |> render_submit()

      assert html =~ ~s(value="not a cron")
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

      view
      |> element("#spiders-coto-by-ean-toggle")
      |> render_click()

      html = confirm_toggle_active(view)

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
        "eans" => "7790070418161,\n7790742307279"
      })
      |> render_change()

      html =
        view
        |> element("#spiders-coto-by-ean-dry-run")
        |> render_click()

      assert html =~ gettext("Dry run")
      assert html =~ "2 EANs"
    end

    test "saves a normalized EAN configuration for by_ean spiders", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html =
        submit_eans(
          view,
          "coto-by-ean",
          "7790070418161, 7790742307279\n7790070418161"
        )

      assert html =~ "save-eans-modal"

      assert html =~
               ngettext(
                 "EAN about to be added",
                 "EANs about to be added",
                 2
               )

      refute html =~ gettext("EAN configuration saved")

      html = confirm_save_eans(view)
      assert html =~ gettext("EAN configuration saved")

      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
        assert Jason.decode!(body) == %{
                 "dry_run" => false,
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
      |> element("#spiders-coto-by-ean-run")
      |> render_click()
    end

    test "saves EANs that are not yet in the product catalog", %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      submit_eans(view, "coto-by-ean", "8445291121867,7891000389300")
      html = confirm_save_eans(view)

      assert html =~ gettext("EAN configuration saved")
      refute html =~ "Unknown EANs"
    end

    test "does not save EANs when the confirmation modal is closed", %{
      conn: conn
    } do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html = submit_eans(view, "coto-by-ean", "7790070418161")

      assert html =~ "save-eans-modal"
      assert html =~ gettext("EAN about to be added")
      refute html =~ gettext("EAN configuration saved")

      html = render_click(view, "cancel_save_eans")

      refute html =~ "save-eans-modal"
      refute html =~ gettext("EAN configuration saved")
    end

    test "shows inline errors instead of the confirmation modal for invalid EANs",
         %{conn: conn} do
      stub_list([spider_json(%{})])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html = submit_eans(view, "coto-by-ean", "ABC,1234")

      refute html =~ "save-eans-modal"

      refute html =~
               ngettext(
                 "EAN about to be added",
                 "EANs about to be added",
                 2
               )

      assert html =~ gettext("%{ean} — must contain only digits", ean: "ABC")

      assert html =~
               gettext("%{ean} — must be 8, 13, or 14 digits long", ean: "1234")
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

    test "hides runtime params when the extractor advertises none", %{
      conn: conn
    } do
      stub_list([
        spider_json(%{
          "name" => "yaguar",
          "supports_dry_run" => false,
          "supports_ean_override" => false,
          "runtime_params" => %{}
        })
      ])

      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "yaguar")

      refute html =~ "spiders-yaguar-params-form"
      refute html =~ gettext("Runtime params")
    end

    test "saves edited runtime params via the extractor API", %{conn: conn} do
      stub_list([spider_with_params()])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      html = expand(view, "coto-by-ean")

      assert html =~ "spiders-coto-by-ean-params-form"
      assert html =~ gettext("Match timeout (ms)")
      assert html =~ gettext("Default: %{value}", value: 2000)

      FakeHttpAdapter.stub(fn :patch, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/params")

        assert Jason.decode!(body) == %{
                 "params" => %{
                   "match_timeout_ms" => 12_000,
                   "debounce_ms" => 1000
                 }
               }

        {:ok, 200,
         spider_with_params(%{
           "runtime_params" =>
             runtime_params_json(%{
               "match_timeout_ms" => %{
                 "type" => "int",
                 "default" => 2000,
                 "value" => 12_000,
                 "description" => "Wait for a product tile."
               }
             })
         })}
      end)

      html =
        view
        |> form("#spiders-coto-by-ean-params-form", %{
          "params" => %{
            "match_timeout_ms" => "12000",
            "debounce_ms" => "1000"
          }
        })
        |> render_submit()

      assert html =~ gettext("Runtime params saved")
      assert html =~ ~s(value="12000")
    end

    test "resets runtime params after confirmation", %{conn: conn} do
      stub_list([
        spider_with_params(%{
          "runtime_params" =>
            runtime_params_json(%{
              "match_timeout_ms" => %{
                "type" => "int",
                "default" => 2000,
                "value" => 12_000,
                "description" => "Wait for a product tile."
              }
            })
        })
      ])

      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      html =
        view
        |> element("#spiders-coto-by-ean-reset-params")
        |> render_click()

      assert html =~ "reset-params-modal"
      assert html =~ gettext("Reset runtime params")

      assert html =~
               gettext(
                 "You are about to reset %{name} wait knobs to class defaults.",
                 name: "coto-by-ean"
               )

      FakeHttpAdapter.stub(fn :patch, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/params")
        assert Jason.decode!(body) == %{"params" => nil}

        {:ok, 200, spider_with_params()}
      end)

      html = confirm_reset_params(view)
      assert html =~ gettext("Runtime params reset to defaults")
      assert html =~ ~s(value="2000")
    end

    test "does not reset runtime params when the confirmation is closed", %{
      conn: conn
    } do
      stub_list([spider_with_params()])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        flunk("closing the reset modal should not call the extractor API")
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-reset-params")
        |> render_click()

      assert html =~ "reset-params-modal"

      html = render_click(view, "cancel_reset_params")
      refute html =~ "reset-params-modal"
    end

    test "sends dirty runtime param diffs with a dry run", %{conn: conn} do
      stub_list([spider_with_params()])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      view
      |> form("#spiders-coto-by-ean-params-form", %{
        "params" => %{
          "match_timeout_ms" => "12000",
          "debounce_ms" => "1000"
        }
      })
      |> render_change()

      FakeHttpAdapter.stub(fn :post, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/run")

        assert Jason.decode!(body) == %{
                 "dry_run" => true,
                 "params" => %{"match_timeout_ms" => 12_000}
               }

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-dry-run")
        |> render_click()

      assert html =~ gettext("Dry run")
    end

    test "does not start a run when a runtime param is invalid", %{
      conn: conn
    } do
      stub_list([spider_with_params()])
      {:ok, view, _html} = live(conn, ~p"/admin/extractor/spiders")
      expand(view, "coto-by-ean")

      view
      |> form("#spiders-coto-by-ean-params-form", %{
        "params" => %{
          "match_timeout_ms" => "abc",
          "debounce_ms" => "1000"
        }
      })
      |> render_change()

      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        flunk("invalid runtime params should not trigger a run")
      end)

      html =
        view
        |> element("#spiders-coto-by-ean-dry-run")
        |> render_click()

      assert html =~
               gettext("%{name} must be an integer",
                 name: gettext("Match timeout (ms)")
               )

      refute html =~ ~s(id="spiders-coto-by-ean-active-run")
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
