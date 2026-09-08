defmodule PriceSpotter.ExtractorTest do
  use PriceSpotter.DataCase, async: false

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Spider

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

      assert invalid_eans == ["ABC", "1234"]
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
