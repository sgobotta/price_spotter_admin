defmodule PriceSpotter.Extractor.ClientTest do
  use ExUnit.Case, async: false

  alias PriceSpotter.Extractor.Client
  alias PriceSpotter.Extractor.FakeHttpAdapter
  alias PriceSpotter.Extractor.Spider

  setup do
    on_exit(fn ->
      Application.delete_env(:price_spotter, :extractor_test_stub)
    end)

    :ok
  end

  describe "list_spiders/0" do
    test "returns spiders built from the JSON response" do
      FakeHttpAdapter.stub(fn :get, url, headers, nil ->
        assert String.ends_with?(url, "/admin/spiders")

        assert {"x-admin-token", _token} =
                 List.keyfind(headers, "x-admin-token", 0)

        {:ok, 200,
         [
           %{
             "id" => "1",
             "name" => "coto-by-ean",
             "cron" => "*/5 * * * *",
             "active" => true,
             "next_run_time" => "2026-09-06T18:45:00-03:00",
             "supports_dry_run" => true,
             "supports_ean_override" => true
           }
         ]}
      end)

      assert {:ok, [%Spider{name: "coto-by-ean", active: true, type: "by_ean"}]} =
               Client.list_spiders()
    end

    test "parses runtime_params from the JSON response" do
      FakeHttpAdapter.stub(fn :get, _url, _headers, nil ->
        {:ok, 200,
         [
           %{
             "id" => "1",
             "name" => "coto-by-ean",
             "cron" => "*/5 * * * *",
             "active" => true,
             "supports_dry_run" => true,
             "supports_ean_override" => true,
             "runtime_params" => %{
               "match_timeout_ms" => %{
                 "type" => "int",
                 "default" => 2000,
                 "value" => 12_000,
                 "description" => "Wait for a product tile."
               }
             }
           }
         ]}
      end)

      assert {:ok, [%Spider{runtime_params: params}]} = Client.list_spiders()

      assert params["match_timeout_ms"]["value"] == 12_000
    end

    test "maps a non-2xx response to an error" do
      FakeHttpAdapter.stub(fn :get, _url, _headers, nil ->
        {:ok, 401, %{"error" => "unauthorized"}}
      end)

      assert {:error, %{status: 401, message: "unauthorized"}} =
               Client.list_spiders()
    end

    test "maps a transport failure to an error" do
      FakeHttpAdapter.stub(fn :get, _url, _headers, nil ->
        {:error, :timeout}
      end)

      assert {:error, %{status: nil, message: _message}} = Client.list_spiders()
    end
  end

  describe "update_schedule/2" do
    test "sends only the given attrs and returns the updated spider" do
      FakeHttpAdapter.stub(fn :patch, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/schedule")
        assert Jason.decode!(body) == %{"active" => true}

        {:ok, 200,
         %{
           "id" => "1",
           "name" => "coto-by-ean",
           "cron" => "*/5 * * * *",
           "active" => true,
           "next_run_time" => nil,
           "supports_dry_run" => true,
           "supports_ean_override" => true
         }}
      end)

      assert {:ok, %Spider{active: true}} =
               Client.update_schedule("coto-by-ean", %{active: true})
    end

    test "maps a 400 response to an error" do
      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        {:ok, 400, %{"error" => "cron does not parse"}}
      end)

      assert {:error, %{status: 400, message: "cron does not parse"}} =
               Client.update_schedule("coto-by-ean", %{cron: "bad"})
    end
  end

  describe "update_params/2" do
    test "sends the overlay and returns the updated spider" do
      FakeHttpAdapter.stub(fn :patch, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/params")

        assert Jason.decode!(body) == %{
                 "params" => %{"match_timeout_ms" => 12_000}
               }

        {:ok, 200,
         %{
           "id" => "1",
           "name" => "coto-by-ean",
           "cron" => "*/5 * * * *",
           "active" => true,
           "supports_dry_run" => true,
           "supports_ean_override" => true,
           "runtime_params" => %{
             "match_timeout_ms" => %{
               "type" => "int",
               "default" => 2000,
               "value" => 12_000,
               "description" => "Wait for a product tile."
             }
           }
         }}
      end)

      assert {:ok, %Spider{runtime_params: params}} =
               Client.update_params("coto-by-ean", %{
                 "match_timeout_ms" => 12_000
               })

      assert params["match_timeout_ms"]["value"] == 12_000
    end

    test "sends null params to clear the overlay" do
      FakeHttpAdapter.stub(fn :patch, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/params")
        assert Jason.decode!(body) == %{"params" => nil}

        {:ok, 200,
         %{
           "id" => "1",
           "name" => "coto-by-ean",
           "cron" => "*/5 * * * *",
           "active" => true,
           "supports_dry_run" => true,
           "supports_ean_override" => true,
           "runtime_params" => %{
             "match_timeout_ms" => %{
               "type" => "int",
               "default" => 2000,
               "value" => 2000,
               "description" => "Wait for a product tile."
             }
           }
         }}
      end)

      assert {:ok, %Spider{}} = Client.update_params("coto-by-ean", nil)
    end

    test "maps a 400 response to an error" do
      FakeHttpAdapter.stub(fn :patch, _url, _headers, _body ->
        {:ok, 400, %{"error" => "unknown runtime param(s)"}}
      end)

      assert {:error, %{status: 400, message: "unknown runtime param(s)"}} =
               Client.update_params("coto-by-ean", %{"nope" => 1})
    end
  end

  describe "trigger_run/2" do
    test "returns the run/stream identifiers" do
      FakeHttpAdapter.stub(fn :post, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/coto-by-ean/run")
        assert Jason.decode!(body) == %{"dry_run" => true}

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      assert {:ok, %{run_id: "run-1", stream_token: "token-1"}} =
               Client.trigger_run("coto-by-ean", dry_run: true)
    end

    test "maps a 404 response to an error" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 404, %{"error" => "unknown spider"}}
      end)

      assert {:error, %{status: 404, message: "unknown spider"}} =
               Client.trigger_run("unknown")
    end

    test "sends the eans list when given" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
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

      assert {:ok, %{run_id: "run-1"}} =
               Client.trigger_run("coto-by-ean",
                 dry_run: true,
                 eans: ["7790070418161", "7790742307279"]
               )
    end

    test "omits eans from the body when the list is empty" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
        assert Jason.decode!(body) == %{"dry_run" => false}

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      assert {:ok, _} =
               Client.trigger_run("coto-by-ean", dry_run: false, eans: [])
    end

    test "maps a 400 response to an error (unsupported eans override)" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 400, %{"error" => "spider does not support eans"}}
      end)

      assert {:error, %{status: 400, message: "spider does not support eans"}} =
               Client.trigger_run("yaguar", eans: ["123"])
    end

    test "sends params when given" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
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

      assert {:ok, %{run_id: "run-1"}} =
               Client.trigger_run("coto-by-ean",
                 dry_run: true,
                 params: %{"match_timeout_ms" => 12_000}
               )
    end

    test "omits params from the body when the overlay is empty" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, body ->
        assert Jason.decode!(body) == %{"dry_run" => false}

        {:ok, 202,
         %{
           "run_id" => "run-1",
           "stream_token" => "token-1",
           "stream_url" => "/admin/spiders/runs/run-1/stream"
         }}
      end)

      assert {:ok, _} =
               Client.trigger_run("coto-by-ean", dry_run: false, params: %{})
    end
  end

  describe "stop_run/1" do
    test "requests a stop for the given run id" do
      FakeHttpAdapter.stub(fn :post, url, _headers, body ->
        assert String.ends_with?(url, "/admin/spiders/runs/run-1/stop")
        assert Jason.decode!(body) == %{}
        {:ok, 202, %{"status" => "stopping"}}
      end)

      assert {:ok, %{"status" => "stopping"}} = Client.stop_run("run-1")
    end

    test "maps a failed stop request to an error" do
      FakeHttpAdapter.stub(fn :post, _url, _headers, _body ->
        {:ok, 404, %{"error" => "run not found"}}
      end)

      assert {:error, %{status: 404, message: "run not found"}} =
               Client.stop_run("missing-run")
    end
  end
end
