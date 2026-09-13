defmodule PriceSpotter.ExtractorTest do
  use PriceSpotter.DataCase, async: false

  import PriceSpotter.MarketplacesFixtures

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.EanMatchDecision
  alias PriceSpotter.Extractor.Spider
  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Repo

  describe "save_input_config/2" do
    test "accepts spiders that only advertise supports_ean_override" do
      spider = %Spider{
        name: "coto-by-ean",
        supports_ean_override: true,
        input_config: %{}
      }

      assert {:ok, %{eans: ["7790070418161"]}} =
               Extractor.save_input_config(spider, "7790070418161")
    end

    test "normalizes comma/newline values and deduplicates" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      assert {:ok, %{eans: ["7790070418161", "7790742307279"]}} =
               Extractor.save_input_config(
                 spider,
                 "7790070418161, 7790742307279\n7790070418161"
               )
    end

    test "returns structured invalid format errors" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      assert {:error,
              %{
                reason: :invalid_format,
                details: %{invalid_eans: invalid_eans}
              }} = Extractor.save_input_config(spider, "ABC,1234")

      assert invalid_eans == [
               %{ean: "ABC", reason: :non_numeric},
               %{ean: "1234", reason: :invalid_length}
             ]
    end

    test "saves EANs that are not yet in the product catalog" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      assert {:ok, %{eans: ["8445291121867", "7891000389300"]}} =
               Extractor.save_input_config(
                 spider,
                 "8445291121867,7891000389300"
               )
    end

    test "handles large payloads by persisting all values" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      large_eans =
        Enum.map_join(1..1_250, ",", fn idx ->
          "9" <> String.pad_leading(Integer.to_string(idx), 12, "0")
        end)

      assert {:ok, %{eans: saved_eans}} =
               Extractor.save_input_config(spider, large_eans)

      assert length(saved_eans) == 1_250
    end
  end

  describe "validate_eans/1" do
    test "returns parsed codes when every EAN is well formed" do
      assert {:ok, ["7790070418161", "7790742307279"]} =
               Extractor.validate_eans(
                 "7790070418161, 7790742307279\n7790070418161"
               )
    end

    test "returns structured invalid format errors without persisting" do
      assert {:error,
              %{
                reason: :invalid_format,
                details: %{invalid_eans: invalid_eans}
              }} = Extractor.validate_eans("ABC,1234")

      assert invalid_eans == [
               %{ean: "ABC", reason: :non_numeric},
               %{ean: "1234", reason: :invalid_length}
             ]
    end
  end

  describe "validate_runtime_params/2" do
    @schema %{
      "match_timeout_ms" => %{
        "type" => "int",
        "default" => 2000,
        "value" => 2000
      },
      "debounce_ms" => %{
        "type" => "int",
        "default" => 1000,
        "value" => 1000
      }
    }

    test "parses integer drafts against the schema" do
      assert {:ok, parsed} =
               Extractor.validate_runtime_params(@schema, %{
                 "match_timeout_ms" => "12000",
                 "debounce_ms" => "0"
               })

      assert parsed == %{
               "match_timeout_ms" => 12_000,
               "debounce_ms" => 0
             }
    end

    test "rejects non-integers and timeout values below 1" do
      assert {:error, %{reason: :invalid_format, details: details}} =
               Extractor.validate_runtime_params(@schema, %{
                 "match_timeout_ms" => "abc",
                 "debounce_ms" => "-1"
               })

      assert details.invalid_params == [
               %{name: "debounce_ms", reason: :out_of_range},
               %{name: "match_timeout_ms", reason: :invalid_format}
             ]
    end

    test "rejects unknown keys" do
      assert {:error, %{reason: :unknown_key, details: details}} =
               Extractor.validate_runtime_params(@schema, %{"nope" => "1"})

      assert details.invalid_params == [
               %{name: "nope", reason: :unknown_key}
             ]
    end
  end

  describe "runtime_param_diffs/2" do
    test "keeps only values that differ from the stored schema value" do
      schema = %{
        "match_timeout_ms" => %{"value" => 2000},
        "debounce_ms" => %{"value" => 1000}
      }

      parsed = %{"match_timeout_ms" => 12_000, "debounce_ms" => 1000}

      assert Extractor.runtime_param_diffs(schema, parsed) == %{
               "match_timeout_ms" => 12_000
             }
    end
  end

  describe "parse_eans/1" do
    test "supports comma and newline separators" do
      assert Extractor.parse_eans("7790070418161,7790742307279\n7790070418161") ==
               [
                 "7790070418161",
                 "7790742307279"
               ]
    end
  end

  describe "candidate set lifecycle" do
    test "upsert stores a pending set grouped by product with candidates" do
      product = product_fixture(%{name: "Yerba Mate 1kg", category: "yerbas"})

      assert {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      assert set.product_id == product.id
      assert set.status == "pending"
      assert [candidate] = set.candidates
      assert candidate.ean_candidate == "7790070418161"
      assert candidate.supplier == "coto"
    end

    test "re-upsert replaces the pending set's candidates" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, _set} = Extractor.upsert_candidate_set(set_attrs(product))

      replacement =
        set_attrs(product, [
          %{
            "ean_candidate" => "7790742307279",
            "name" => "Yerba Mate 500g",
            "supplier" => "carrefour"
          }
        ])

      assert {:ok, set} = Extractor.upsert_candidate_set(replacement)
      assert [candidate] = set.candidates
      assert candidate.ean_candidate == "7790742307279"

      assert [only_set] = Extractor.list_pending_candidate_sets()
      assert only_set.id == set.id
    end

    test "list supports filtering by name, ean candidate, supplier, category" do
      coto =
        product_fixture(%{
          name: "Yerba Mate 1kg",
          category: "yerbas",
          internal_id: "coto-yerba-1"
        })

      other =
        product_fixture(%{
          name: "Cafe Molido",
          category: "cafes",
          internal_id: "carrefour-cafe-1"
        })

      {:ok, _} = Extractor.upsert_candidate_set(set_attrs(coto))

      {:ok, _} =
        Extractor.upsert_candidate_set(
          set_attrs(other, [
            %{
              "ean_candidate" => "7891000389300",
              "name" => "Cafe Molido 250g",
              "supplier" => "carrefour"
            }
          ])
        )

      assert [%{product_id: id}] =
               Extractor.list_pending_candidate_sets(%{name: "yerba"})

      assert id == coto.id

      assert [%{product_id: ^id}] =
               Extractor.list_pending_candidate_sets(%{
                 ean_candidate: "7790070418161"
               })

      assert [%{product_id: ^id}] =
               Extractor.list_pending_candidate_sets(%{supplier: "coto"})

      assert [%{product_id: other_id}] =
               Extractor.list_pending_candidate_sets(%{category: "cafes"})

      assert other_id == other.id
    end

    test "approval persists a decision, applies the EAN, removes the set" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      assert {:ok, %{decision: decision, product: updated}} =
               Extractor.approve_candidate(set, "7790070418161")

      assert decision.decision == "approved"
      assert decision.ean_candidate == "7790070418161"
      assert updated.ean == "7790070418161"

      assert Marketplaces.get_product!(product.id).ean == "7790070418161"
      assert Extractor.list_pending_candidate_sets() == []
      assert Repo.aggregate(EanMatchDecision, :count) == 1
    end

    test "disapproval persists a decision and removes the set without touching the product" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      assert {:ok, %{decision: decision}} =
               Extractor.disapprove_candidate(set, "7790070418161")

      assert decision.decision == "disapproved"
      assert Marketplaces.get_product!(product.id).ean == nil
      assert Extractor.list_pending_candidate_sets() == []
      assert Repo.aggregate(EanMatchDecision, :count) == 1
    end

    test "approval of an EAN not in the set is rejected without side effects" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      assert {:error, :candidate_not_found} =
               Extractor.approve_candidate(set, "0000000000000")

      assert Marketplaces.get_product!(product.id).ean == nil
      assert [only_set] = Extractor.list_pending_candidate_sets()
      assert only_set.id == set.id
      assert Repo.aggregate(EanMatchDecision, :count) == 0
    end

    test "approval does not overwrite a barcode assigned after the set was created" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      product
      |> Ecto.Changeset.change(%{ean: "7790000000031"})
      |> Repo.update!()

      assert {:error, :product_has_ean} =
               Extractor.approve_candidate(set, "7790070418161")

      assert Marketplaces.get_product!(product.id).ean == "7790000000031"
      assert [only_set] = Extractor.list_pending_candidate_sets()
      assert only_set.id == set.id
      assert Repo.aggregate(EanMatchDecision, :count) == 0
    end

    test "disapproval of an EAN not in the set is rejected without side effects" do
      product = product_fixture(%{name: "Yerba Mate 1kg"})
      {:ok, set} = Extractor.upsert_candidate_set(set_attrs(product))

      assert {:error, :candidate_not_found} =
               Extractor.disapprove_candidate(set, "0000000000000")

      assert [only_set] = Extractor.list_pending_candidate_sets()
      assert only_set.id == set.id
      assert Repo.aggregate(EanMatchDecision, :count) == 0
    end
  end

  defp set_attrs(product, candidates \\ nil) do
    %{
      "product_id" => product.id,
      "product_name" => product.name,
      "category" => product.category,
      "candidates" =>
        candidates ||
          [
            %{
              "ean_candidate" => "7790070418161",
              "name" => "Yerba Mate 1kg Coto",
              "supplier" => "coto",
              "url" => "https://coto.example/p/1",
              "image_url" => "https://coto.example/img/1.png",
              "price" => "1200.50",
              "last_fetched_at" => "2026-09-08T05:00:00Z"
            }
          ]
    }
  end
end
