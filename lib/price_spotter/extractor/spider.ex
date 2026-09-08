defmodule PriceSpotter.Extractor.Spider do
  @moduledoc """
  A spider entry as reported by the extractor service's `GET /admin/spiders`.

  This is not persisted locally - the extractor service is the source of
  truth (see `PriceSpotter.Extractor.Client`), this struct only shapes its
  JSON responses for use in the admin UI.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          type: String.t() | nil,
          cron: String.t(),
          active: boolean(),
          next_run_time: String.t() | nil,
          supports_dry_run: boolean(),
          supports_ean_override: boolean(),
          input_config: map()
        }

  defstruct [
    :id,
    :name,
    :type,
    :cron,
    :active,
    :next_run_time,
    :supports_dry_run,
    :supports_ean_override,
    input_config: %{}
  ]

  @doc """
  Builds a spider struct from a decoded JSON map (as returned by any of the
  extractor service's `/admin/spiders` endpoints).
  """
  @spec from_json(map()) :: t()
  def from_json(%{} = json) do
    %__MODULE__{
      id: json["id"],
      name: json["name"],
      type: json["type"] || inferred_type(json["supports_ean_override"]),
      cron: json["cron"],
      active: json["active"],
      next_run_time: json["next_run_time"],
      supports_dry_run: json["supports_dry_run"],
      supports_ean_override: json["supports_ean_override"],
      input_config: json["input_config"] || %{}
    }
  end

  @doc """
  True when the spider accepts a persisted EAN list. The extractor API
  may omit `type` and only send `supports_ean_override`.
  """
  @spec ean_configurable?(t()) :: boolean()
  def ean_configurable?(%__MODULE__{supports_ean_override: true}), do: true
  def ean_configurable?(%__MODULE__{type: "by_ean"}), do: true
  def ean_configurable?(_spider), do: false

  defp inferred_type(true), do: "by_ean"
  defp inferred_type(_supports_ean_override), do: nil
end
