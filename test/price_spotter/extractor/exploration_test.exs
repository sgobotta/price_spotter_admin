defmodule PriceSpotter.Extractor.ExplorationTest do
  use PriceSpotter.DataCase, async: false

  import PriceSpotter.MarketplacesFixtures

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Exploration
  alias PriceSpotter.Extractor.FakeLlmClient
  alias PriceSpotter.Marketplaces.SuppliersFixtures

  # 13-digit EANs (numeric) so Product's changeset keeps them.
  @ean_match "7790000000017"
  @ean_mismatch "7790000000024"

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
