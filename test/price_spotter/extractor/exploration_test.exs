defmodule PriceSpotter.Extractor.ExplorationTest do
  use PriceSpotter.DataCase, async: false

  import PriceSpotter.MarketplacesFixtures

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Exploration
  alias PriceSpotter.Extractor.FakeHttpAdapter
  alias PriceSpotter.Extractor.FakeLlmClient
  alias PriceSpotter.Marketplaces.SuppliersFixtures

  # 13-digit EANs (numeric) so Product's changeset keeps them.
  @ean_match "7790000000017"
  @ean_mismatch "7790000000024"
  @ean_other "7790000000031"

  # supplier_name values as emitted by the extractor spiders; these are the
  # keys of the :ean_override_spider_by_supplier config map (config/config.exs)
  # and are not always identical to the spider key ("maxiconsumo" spider is
  # "maxiconsumo-by-ean-v2").
  @coto_supplier "coto-by-ean"
  @maxi_supplier "maxiconsumo"

  # The fake LLM stub lives in Application env, which persists across tests;
  # clear it around each test so ordering can't leak a stub between them.
  setup do
    FakeLlmClient.clear()
    on_exit(&FakeLlmClient.clear/0)
    :ok
  end

  # A product's fixture derives its supplier from the product name, so each
  # product needs a uniquely-named supplier to avoid the supplier unique index.
  defp unique_supplier_id do
    supplier =
      SuppliersFixtures.create(%{
        name: "sup-#{System.unique_integer([:positive])}"
      })

    supplier.id
  end

  defp no_ean_product(name) do
    product_fixture(%{
      name: name,
      supplier_id: unique_supplier_id(),
      internal_id: "int-#{System.unique_integer([:positive])}"
    })
  end

  defp product_with_ean(name, ean, supplier) do
    product_fixture(%{
      name: name,
      ean: ean,
      supplier_name: supplier,
      supplier_id: unique_supplier_id(),
      internal_id: "int-#{System.unique_integer([:positive])}"
    })
  end

  defp spider_json(name, override?) do
    %{
      "id" => name,
      "name" => name,
      "cron" => "0 0 * * *",
      "active" => true,
      "next_run_time" => nil,
      "supports_dry_run" => override?,
      "supports_ean_override" => override?
    }
  end

  # Stubs GET /admin/spiders with `spiders` and forwards every POST .../run to
  # the test process as {:run, spider_key, eans} so routing can be asserted.
  defp stub_spiders_and_capture_runs(spiders) do
    test_pid = self()

    FakeHttpAdapter.stub(fn
      :get, url, _headers, nil ->
        assert String.ends_with?(url, "/admin/spiders")
        {:ok, 200, spiders}

      :post, url, _headers, body ->
        key =
          url
          |> String.split("/admin/spiders/")
          |> List.last()
          |> String.trim_trailing("/run")

        %{"eans" => eans} = Jason.decode!(body)
        send(test_pid, {:run, key, eans})

        {:ok, 200,
         %{"run_id" => "r", "stream_token" => "t", "stream_url" => "u"}}
    end)
  end

  describe "explore_product/2 weight/unit safeguard" do
    test "drops size-mismatched candidates even when the LLM endorses them" do
      target = no_ean_product("Fideos Tirabuzon Marca X 200g")

      product_with_ean("Fideos Tirabuzon Marca X 200g", @ean_match, "Coto")
      product_with_ean("Fideos Tirabuzon Marca X 400g", @ean_mismatch, "Dia")

      # The model endorses *both* references, including the 400g one.
      FakeLlmClient.stub(:endorse_all)

      assert {:ok, result} = Exploration.explore_product(target)

      # Post-processing keeps only the 200g match.
      assert result.candidate_count == 1
      assert result.size_rejections == 1

      eans = Enum.map(result.set.candidates, & &1.ean_candidate)
      assert eans == [@ean_match]
    end

    test "returns :no_references when nothing similar has an EAN" do
      target = no_ean_product("Producto Totalmente Unico Zzz 123")

      FakeLlmClient.stub(:endorse_all)

      assert {:ok, :no_references} = Exploration.explore_product(target)
    end

    test "returns :no_candidates when the model endorses nothing" do
      target = no_ean_product("Arroz Largo Fino Marca Y 1kg")
      product_with_ean("Arroz Largo Fino Marca Y 1kg", @ean_match, "Coto")

      FakeLlmClient.stub(fn _target, _refs, _opts -> {:ok, []} end)

      assert {:ok, :no_candidates} = Exploration.explore_product(target)
    end

    test "propagates an LLM error without writing a candidate set" do
      target = no_ean_product("Leche Entera Marca Z 1L")
      product_with_ean("Leche Entera Marca Z 1L", @ean_match, "Coto")

      FakeLlmClient.stub(fn _t, _r, _o -> {:error, :llm_unreachable} end)

      assert {:error, :llm_unreachable} = Exploration.explore_product(target)
      assert Extractor.list_pending_candidate_sets() == []
    end

    test "accepts a numeric-string :similarity without crashing" do
      target = no_ean_product("Fideos Tirabuzon Marca X 200g")
      product_with_ean("Fideos Tirabuzon Marca X 200g", @ean_match, "Coto")

      FakeLlmClient.stub(:endorse_all)

      # A threshold arriving as a string (env/config/params) must be parsed and
      # clamped, not raise a FunctionClauseError before the transaction.
      assert {:ok, result} =
               Exploration.explore_product(target, similarity: "0.1")

      assert result.candidate_count == 1
    end

    test "falls back to the default when :similarity is unparseable" do
      target = no_ean_product("Fideos Tirabuzon Marca X 200g")
      product_with_ean("Fideos Tirabuzon Marca X 200g", @ean_match, "Coto")

      FakeLlmClient.stub(:endorse_all)

      assert {:ok, result} =
               Exploration.explore_product(target, similarity: "garbage")

      assert result.candidate_count == 1
    end
  end

  describe "explore_product/2 fetch_prices supplier routing" do
    setup do
      on_exit(fn ->
        Application.delete_env(:price_spotter, :extractor_test_stub)
      end)

      :ok
    end

    test "routes each supplier's EANs to its own by-ean spider" do
      target = no_ean_product("Fideos Tirabuzon Marca X 200g")

      product_with_ean(
        "Fideos Tirabuzon Marca X 200g",
        @ean_match,
        @coto_supplier
      )

      product_with_ean(
        "Fideos Tirabuzon Marca X 200g",
        @ean_other,
        @maxi_supplier
      )

      FakeLlmClient.stub(:endorse_all)

      stub_spiders_and_capture_runs([
        spider_json("coto-by-ean", true),
        spider_json("maxiconsumo-by-ean-v2", true)
      ])

      assert {:ok, result} =
               Exploration.explore_product(target, fetch_prices: true)

      assert result.candidate_count == 2

      # Each supplier's EAN goes to the spider that matches that supplier -
      # never a single hardcoded spider for all of them.
      assert_receive {:run, "coto-by-ean", [@ean_match]}
      assert_receive {:run, "maxiconsumo-by-ean-v2", [@ean_other]}
    end

    test "skips a supplier that has no EAN-override spider" do
      target = no_ean_product("Arroz Largo Fino Marca Y 1kg")

      product_with_ean(
        "Arroz Largo Fino Marca Y 1kg",
        @ean_match,
        @coto_supplier
      )

      # "yaguar" is not in the config map, so it must not be fetched.
      product_with_ean("Arroz Largo Fino Marca Y 1kg", @ean_other, "yaguar")

      FakeLlmClient.stub(:endorse_all)

      stub_spiders_and_capture_runs([
        spider_json("coto-by-ean", true),
        spider_json("maxiconsumo-by-ean-v2", true)
      ])

      assert {:ok, result} =
               Exploration.explore_product(target, fetch_prices: true)

      assert result.candidate_count == 2
      assert_receive {:run, "coto-by-ean", [@ean_match]}
      refute_receive {:run, _key, [@ean_other]}
    end

    test "skips fetches when the extractor spider list is unavailable" do
      target = no_ean_product("Leche Entera Marca Z 1L")
      product_with_ean("Leche Entera Marca Z 1L", @ean_match, @coto_supplier)

      FakeLlmClient.stub(:endorse_all)

      test_pid = self()

      FakeHttpAdapter.stub(fn
        :get, _url, _headers, nil ->
          {:error, :timeout}

        :post, _url, _headers, _body ->
          send(test_pid, :unexpected_run)
          {:ok, 200, %{}}
      end)

      assert {:ok, result} =
               Exploration.explore_product(target, fetch_prices: true)

      assert result.candidate_count == 1
      refute_receive :unexpected_run
    end

    test "does not fetch prices when fetch_prices is not requested" do
      target = no_ean_product("Yerba Mate Marca Q 1kg")
      product_with_ean("Yerba Mate Marca Q 1kg", @ean_match, @coto_supplier)

      FakeLlmClient.stub(:endorse_all)

      test_pid = self()

      FakeHttpAdapter.stub(fn _method, _url, _headers, _body ->
        send(test_pid, :unexpected_call)
        {:ok, 200, %{}}
      end)

      assert {:ok, result} = Exploration.explore_product(target)

      assert result.candidate_count == 1
      refute_receive :unexpected_call
    end
  end

  describe "run_for_product/2 no-EAN precondition" do
    test "explores a product that still has no EAN" do
      target = no_ean_product("Aceite Girasol Marca A 900ml")
      product_with_ean("Aceite Girasol Marca A 900ml", @ean_match, "Coto")

      FakeLlmClient.stub(:endorse_all)

      assert {:ok, run} = Exploration.run_for_product(target, [])
      assert run.status == "completed"
      assert run.trigger == "manual"

      assert {:ok, run_by_id} = Exploration.run_for_product(target.id, [])
      assert run_by_id.status == "completed"
    end

    test "refuses a product that already has an EAN" do
      product =
        product_with_ean("Fideos Tirabuzon Marca X 200g", @ean_match, "Coto")

      FakeLlmClient.stub(:endorse_all)

      assert {:error, :product_has_ean} =
               Exploration.run_for_product(product, [])

      assert {:error, :product_has_ean} =
               Exploration.run_for_product(product.id, [])

      assert Extractor.list_pending_candidate_sets() == []
    end

    test "reloads a stale struct so a newly assigned EAN cannot be overwritten" do
      product = no_ean_product("Yerba Mate Marca Q 1kg")
      product_with_ean("Yerba Mate Marca Q 1kg", @ean_match, "Coto")

      product
      |> Ecto.Changeset.change(%{ean: @ean_other})
      |> Repo.update!()

      FakeLlmClient.stub(:endorse_all)

      assert {:error, :product_has_ean} =
               Exploration.run_for_product(product, [])

      assert Extractor.list_pending_candidate_sets() == []
    end
  end

  describe "run_monthly/1 scheduler execution path" do
    test "records a completed run with logs and upserts candidate sets" do
      no_ean_product("Aceite Girasol Marca A 900ml")
      product_with_ean("Aceite Girasol Marca A 900ml", @ean_match, "Coto")

      FakeLlmClient.stub(:endorse_all)

      assert {:ok, run} = Exploration.run_monthly()

      assert run.status == "completed"
      assert run.trigger == "scheduled"
      assert run.products_scanned >= 1
      assert run.candidate_sets_upserted >= 1
      assert run.candidates_proposed >= 1
      refute is_nil(run.finished_at)

      assert Enum.any?(run.logs, &(&1["message"] == "Exploration started"))
      assert Enum.any?(run.logs, &(&1["message"] == "Exploration finished"))

      assert [set] = Extractor.list_pending_candidate_sets()
      assert Enum.map(set.candidates, & &1.ean_candidate) == [@ean_match]
    end

    test "honors the :limit option" do
      no_ean_product("Galletitas Dulces Marca B 300g")
      no_ean_product("Galletitas Saladas Marca C 300g")

      FakeLlmClient.stub(:endorse_all)

      assert {:ok, run} = Exploration.run_monthly(limit: 1)
      assert run.products_scanned == 1
    end
  end
end
