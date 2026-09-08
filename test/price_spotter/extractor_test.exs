defmodule PriceSpotter.ExtractorTest do
  use PriceSpotter.DataCase, async: false

  alias Decimal, as: D
  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Spider
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotter.Repo

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

  describe "save_input_config/2" do
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
              %{reason: :invalid_format, details: %{invalid_eans: invalid_eans}}} =
               Extractor.save_input_config(spider, "ABC,1234")

      assert invalid_eans == ["ABC", "1234"]
    end

    test "returns structured unknown EAN errors" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      assert {:error,
              %{reason: :unknown_eans, details: %{unknown_eans: unknown_eans}}} =
               Extractor.save_input_config(spider, "7790070418161,99999999")

      assert unknown_eans == ["99999999"]
    end

    test "handles large payloads by returning unknown values cleanly" do
      spider = %Spider{name: "coto-by-ean", type: "by_ean", input_config: %{}}

      large_unknowns =
        1..1_250
        |> Enum.map(fn idx ->
          "9" <> String.pad_leading(Integer.to_string(idx), 12, "0")
        end)
        |> Enum.join(",")

      assert {:error,
              %{reason: :unknown_eans, details: %{unknown_eans: unknown_eans}}} =
               Extractor.save_input_config(spider, large_unknowns)

      assert length(unknown_eans) == 1_250
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
end
