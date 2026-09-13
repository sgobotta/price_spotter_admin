defmodule PriceSpotter.Extractor.PackageSizeTest do
  use ExUnit.Case, async: true

  alias PriceSpotter.Extractor.PackageSize

  describe "parse/1" do
    test "parses grams" do
      assert %{dimension: :mass, base: 500.0} =
               PackageSize.parse("Fideos 500 g")
    end

    test "parses kilograms into grams" do
      assert %{dimension: :mass, base: 1000.0} = PackageSize.parse("Yerba 1kg")
    end

    test "parses millilitres" do
      assert %{dimension: :volume, base: 900.0} =
               PackageSize.parse("Aceite Girasol 900ml")
    end

    test "parses litres with a decimal comma into millilitres" do
      assert %{dimension: :volume, base: 1500.0} =
               PackageSize.parse("Gaseosa 1,5 L")
    end

    test "parses a simple multipack without collapsing pack into volume" do
      assert %{dimension: :volume, base: 500.0, pack: 6.0} =
               PackageSize.parse("Agua Mineral 6x500ml")
    end

    test "parses a multipack with an uppercase X" do
      assert %{dimension: :volume, base: 500.0, pack: 6.0} =
               PackageSize.parse("Agua Mineral 6X500ml")
    end

    test "parses a hyphenated 6-pack as a count" do
      assert %{dimension: :count, base: 6.0, pack: 1.0} =
               PackageSize.parse("Producto 6-pack")
    end

    test "parses pack x N as a count" do
      assert %{dimension: :count, base: 6.0, pack: 1.0} =
               PackageSize.parse("Cerveza pack x 6")
    end

    test "parses pack de N as a count" do
      assert %{dimension: :count, base: 6.0, pack: 1.0} =
               PackageSize.parse("Cerveza pack de 6")
    end

    test "combines a 6-pack spelling with a unit size" do
      assert %{dimension: :volume, base: 330.0, pack: 6.0} =
               PackageSize.parse("Cerveza 6-pack 330ml")
    end

    test "uses the last size token when several are present" do
      assert %{dimension: :mass, base: 500.0} =
               PackageSize.parse("Fideos 4 quesos x 500 g")
    end

    test "returns nil when no size is present" do
      assert PackageSize.parse("Producto sin tamaño") == nil
    end

    test "returns :unparsed_pack when a pack marker has no count" do
      assert PackageSize.parse("Producto pack familiar") == :unparsed_pack
    end

    test "returns :unparsed_pack when an unquantified pack marker precedes a size" do
      assert PackageSize.parse("Producto pack familiar 500ml") ==
               :unparsed_pack
    end

    test "keeps a multipack size even when the name also says pack" do
      assert %{dimension: :volume, base: 500.0, pack: 6.0} =
               PackageSize.parse("Producto pack familiar 6x500ml")
    end
  end

  describe "compatible?/2" do
    test "equal sizes are compatible" do
      assert PackageSize.compatible?("Fideos 500g", "Fideos Otra Marca 500 g")
    end

    test "equal sizes across units are compatible" do
      assert PackageSize.compatible?("Yerba 1kg", "Yerba Suave 1000 g")
    end

    test "different weights are NOT compatible" do
      refute PackageSize.compatible?("Fideos 200g", "Fideos 400g")
    end

    test "close-but-different weights are NOT compatible (hard constraint)" do
      refute PackageSize.compatible?("Harina 999g", "Harina 1kg")
    end

    test "different dimensions are NOT compatible" do
      refute PackageSize.compatible?("Producto 500 g", "Producto 500 ml")
    end

    test "no size on either side is compatible" do
      assert PackageSize.compatible?("Producto A", "Producto B")
    end

    test "a size on only one side is NOT compatible" do
      refute PackageSize.compatible?("Producto", "Producto 500 g")
    end

    test "a 6-pack is NOT compatible with an unquantified single" do
      refute PackageSize.compatible?("Producto 6-pack", "Producto")
    end

    test "matching 6-pack spellings are compatible" do
      assert PackageSize.compatible?("Producto 6-pack", "Producto pack x 6")
    end

    test "a 6-pack is compatible with 6 unidades" do
      assert PackageSize.compatible?("Producto 6-pack", "Producto 6 unidades")
    end

    test "a 6x500ml multipack is NOT compatible with a single 3000ml" do
      refute PackageSize.compatible?(
               "Agua Mineral 6x500ml",
               "Agua Mineral 3000ml"
             )
    end

    test "matching multipacks are compatible" do
      assert PackageSize.compatible?("Agua Mineral 6x500ml", "Agua 6x500 ml")
    end

    test "an unparsed pack marker is NOT compatible with a single" do
      refute PackageSize.compatible?("Producto pack familiar", "Producto")
    end

    test "an unquantified pack marker plus size is NOT a plain 500ml" do
      refute PackageSize.compatible?(
               "Producto pack familiar 500ml",
               "Producto 500ml"
             )
    end
  end
end
