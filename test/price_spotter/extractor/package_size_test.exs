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

    test "parses a simple multipack" do
      assert %{dimension: :volume, base: 3000.0} =
               PackageSize.parse("Agua Mineral 6x500ml")
    end

    test "parses a multipack with an uppercase X" do
      assert %{dimension: :volume, base: 3000.0} =
               PackageSize.parse("Agua Mineral 6X500ml")
    end

    test "uses the last size token when several are present" do
      assert %{dimension: :mass, base: 500.0} =
               PackageSize.parse("Fideos 4 quesos x 500 g")
    end

    test "returns nil when no size is present" do
      assert PackageSize.parse("Producto sin tamaño") == nil
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
  end
end
