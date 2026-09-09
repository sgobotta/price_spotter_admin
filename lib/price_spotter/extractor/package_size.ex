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
  equal.

  Names are Argentine Spanish (es_AR), so units cover both English and
  Spanish spellings (g/gr/gramos, kg/kilo(s), l/lt/litro(s), ml/cc, ...).
  Decimal commas ("1,5 l") and simple multipacks ("6x500ml", "3 u x 1 l")
  are supported.
  """

  @typedoc """
  A normalized package size: a magnitude expressed in the dimension's base
  unit (grams for mass, millilitres for volume, units for count).
  """
  @type t :: %{dimension: :mass | :volume | :count, base: float()}

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
  @size_regex ~r/(?:(\d+)\s*[x×]\s*)?(\d+(?:[.,]\d+)?)\s*([a-zA-Zµ]+)\.?/u

  # Floating-point comparison tolerance (0.1% of the larger magnitude) so
  # "1kg" and "1000g" compare equal despite representation.
  @rel_tolerance 0.001

  @doc """
  Extracts the package size from a product name, or `nil` when none is found.

  When a name carries several size tokens (e.g. a brand line plus the pack
  size) the *last* recognized token wins, since the package size is
  conventionally written at the end of the name.
  """
  @spec parse(String.t() | nil) :: t() | nil
  def parse(nil), do: nil

  def parse(name) when is_binary(name) do
    @size_regex
    |> Regex.scan(name)
    |> Enum.map(&build_size/1)
    |> Enum.reject(&is_nil/1)
    |> List.last()
  end

  @doc """
  Whether two product names may describe the same package size.

  Rules (conservative by design):

    * both sizes parse and are equal in the same dimension -> `true`
    * neither name has a parseable size -> `true` (no evidence either way)
    * exactly one name has a parseable size -> `false`
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
  @spec equal?(t() | nil, t() | nil) :: boolean()
  def equal?(nil, nil), do: true
  def equal?(nil, _size), do: false
  def equal?(_size, nil), do: false

  def equal?(%{dimension: dim, base: a}, %{dimension: dim, base: b}) do
    abs(a - b) <= max(abs(a), abs(b)) * @rel_tolerance
  end

  def equal?(_a, _b), do: false

  defp build_size([_full, count, magnitude, unit]) do
    case Map.fetch(@units, String.downcase(unit)) do
      {:ok, {dimension, factor}} ->
        %{
          dimension: dimension,
          base: to_number(magnitude) * factor * multiplier(count)
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
