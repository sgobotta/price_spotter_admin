defmodule PriceSpotter.Extractor.PackageSize do
  @moduledoc """
  Parses and compares the package size (weight/volume/count) encoded in a
  product name.

  This is the hard safeguard behind the EAN exploration flow: a 200g noodle
  and a 400g noodle share a name but are different products with different
  EANs, so a match candidate is only ever allowed between products whose
  package size is *compatible* (see `compatible?/2`). The comparison is
  intentionally conservative - when one side has a parseable size and the
  other does not, the sizes are treated as incompatible rather than assumed
  equal. Pack cardinality is part of the identity: a 6-pack is not a single,
  and `6x500ml` is not a single 3000 ml bottle.

  Names are Argentine Spanish (es_AR), so units cover both English and
  Spanish spellings (g/gr/gramos, kg/kilo(s), l/lt/litro(s), ml/cc, ...).
  Decimal commas ("1,5 l") are supported, as is the adjacent multipack form
  where the count directly precedes the size ("6x500ml" -> 6 packs of 500 ml).
  Hyphenated and spelled-out packs ("6-pack", "pack x 6", "pack de 6") are
  recognized as a count. Spaced forms such as "3 u x 1 l" are not treated as
  a multiplier - the trailing size token wins ("1 l").
  """

  @typedoc """
  A normalized package size: a magnitude expressed in the dimension's base
  unit (grams for mass, millilitres for volume, units for count), plus the
  pack cardinality (`1.0` for a single package).
  """
  @type t :: %{
          dimension: :mass | :volume | :count,
          base: float(),
          pack: float()
        }

  @type parse_result :: t() | :unparsed_pack | nil

  # unit token (lowercased) => {dimension, factor to the base unit}
  @units %{
    "mg" => {:mass, 0.001},
    "g" => {:mass, 1.0},
    "gr" => {:mass, 1.0},
    "grs" => {:mass, 1.0},
    "grm" => {:mass, 1.0},
    "grms" => {:mass, 1.0},
    "gramo" => {:mass, 1.0},
    "gramos" => {:mass, 1.0},
    "kg" => {:mass, 1000.0},
    "kgs" => {:mass, 1000.0},
    "kilo" => {:mass, 1000.0},
    "kilos" => {:mass, 1000.0},
    "kilogramo" => {:mass, 1000.0},
    "kilogramos" => {:mass, 1000.0},
    "ml" => {:volume, 1.0},
    "cc" => {:volume, 1.0},
    "cl" => {:volume, 10.0},
    "l" => {:volume, 1000.0},
    "lt" => {:volume, 1000.0},
    "lts" => {:volume, 1000.0},
    "litro" => {:volume, 1000.0},
    "litros" => {:volume, 1000.0},
    "u" => {:count, 1.0},
    "un" => {:count, 1.0},
    "unid" => {:count, 1.0},
    "unidad" => {:count, 1.0},
    "unidades" => {:count, 1.0}
  }

  # A size token: an optional "N x" multiplier, a decimal magnitude, and a
  # unit. `\b`-free on the unit side so "500g" (no space) matches too.
  @size_regex ~r/(?:(\d+)\s*[xX×]\s*)?(\d+(?:[.,]\d+)?)\s*([a-zA-Zµ]+)\.?/u

  # "6-pack" / "6 pack" / "6pack", or "pack x 6" / "pack de 6".
  @pack_count_regex ~r/(?:(\d+)\s*-?\s*packs?\b)|(?:\bpacks?\s*(?:x|×|de)\s*(\d+))/iu

  # A pack spelling we could not quantify (e.g. "pack familiar").
  @pack_marker_regex ~r/(?:^|[\s\-])packs?(?:$|[\s\-.,])/iu

  # Relative tolerance for the equality check. This is a HARD constraint, so
  # the tolerance only absorbs floating-point roundoff (~1e-12 here) - it must
  # not treat genuinely different sizes as equal (e.g. 999 g vs 1 kg). "1kg"
  # and "1000g" still compare equal because both normalize to 1000.0 exactly.
  @rel_tolerance 1.0e-9

  @doc """
  Extracts the package size from a product name, or `nil` when none is found.

  When a name carries several size tokens (e.g. a brand line plus the pack
  size) the *last* recognized token wins, since the package size is
  conventionally written at the end of the name.

  Returns `:unparsed_pack` when the name contains a pack marker that cannot
  be quantified, so it is never treated as compatible with a single or with
  another unparsed pack.
  """
  @spec parse(String.t() | nil) :: parse_result()
  def parse(nil), do: nil

  def parse(name) when is_binary(name) do
    size = last_size(name)
    pack_count = last_pack_count(name)

    cond do
      is_map(size) ->
        merge_pack(size, pack_count)

      is_number(pack_count) ->
        %{dimension: :count, base: pack_count, pack: 1.0}

      pack_marker?(name) ->
        :unparsed_pack

      true ->
        nil
    end
  end

  @doc """
  Whether two product names may describe the same package size.

  Rules (conservative by design):

    * both sizes parse and are equal in the same dimension and pack -> `true`
    * neither name has a parseable size or pack marker -> `true`
    * exactly one name has a parseable size -> `false`
    * pack cardinality differs (6-pack vs single, 6x500ml vs 3000ml) -> `false`
    * an unquantified pack marker is present -> `false`
    * sizes differ, or differ in dimension -> `false`
  """
  @spec compatible?(String.t() | nil, String.t() | nil) :: boolean()
  def compatible?(name_a, name_b) do
    equal?(parse(name_a), parse(name_b))
  end

  @doc """
  Compares two already-parsed sizes with the same semantics as
  `compatible?/2`.
  """
  @spec equal?(parse_result(), parse_result()) :: boolean()
  def equal?(:unparsed_pack, _size), do: false
  def equal?(_size, :unparsed_pack), do: false
  def equal?(nil, nil), do: true
  def equal?(nil, _size), do: false
  def equal?(_size, nil), do: false

  def equal?(
        %{dimension: dim, base: a, pack: pack_a},
        %{dimension: dim, base: b, pack: pack_b}
      ) do
    within_tolerance?(pack_a, pack_b) and within_tolerance?(a, b)
  end

  def equal?(_a, _b), do: false

  defp last_size(name) do
    @size_regex
    |> Regex.scan(name)
    |> Enum.map(&build_size/1)
    |> Enum.reject(&is_nil/1)
    |> List.last()
  end

  defp last_pack_count(name) do
    @pack_count_regex
    |> Regex.scan(name)
    |> Enum.map(&pack_count_from_scan/1)
    |> Enum.reject(&is_nil/1)
    |> List.last()
  end

  defp pack_count_from_scan([_full, count, empty])
       when is_binary(count) and empty in [nil, ""] do
    to_number(count)
  end

  defp pack_count_from_scan([_full, empty, count])
       when empty in [nil, ""] and is_binary(count) do
    to_number(count)
  end

  defp pack_count_from_scan([_full, count]) when is_binary(count) do
    to_number(count)
  end

  defp pack_count_from_scan(_other), do: nil

  defp pack_marker?(name), do: Regex.match?(@pack_marker_regex, name)

  defp merge_pack(size, nil), do: size

  defp merge_pack(
         %{dimension: :count, pack: pack, base: base} = size,
         pack_count
       )
       when pack == 1.0 do
    # "pack x 6 u": the count token and the pack spelling are the same quantity.
    if within_tolerance?(base, pack_count) do
      size
    else
      %{size | pack: pack_count}
    end
  end

  defp merge_pack(%{pack: pack} = size, pack_count) when pack == 1.0 do
    %{size | pack: pack_count}
  end

  defp merge_pack(size, _pack_count), do: size

  defp build_size([_full, count, magnitude, unit]) do
    case Map.fetch(@units, String.downcase(unit)) do
      {:ok, {dimension, factor}} ->
        %{
          dimension: dimension,
          base: to_number(magnitude) * factor,
          pack: multiplier(count)
        }

      :error ->
        nil
    end
  end

  # An absent multiplier capture group comes back as "" from Regex.scan/2;
  # guard nil too so a single-size name can never reach to_number/1 with a
  # non-binary.
  defp multiplier(count) when count in [nil, ""], do: 1.0
  defp multiplier(count), do: to_number(count)

  defp within_tolerance?(a, b) do
    abs(a - b) <= max(abs(a), abs(b)) * @rel_tolerance
  end

  defp to_number(value) do
    value
    |> String.replace(",", ".")
    |> Float.parse()
    |> case do
      {number, _rest} -> number
      :error -> 0.0
    end
  end
end
