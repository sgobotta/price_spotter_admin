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

      assert {:ok, [%Spider{name: "coto-by-ean", active: true}]} =
               Client.list_spiders()
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
  end
end
