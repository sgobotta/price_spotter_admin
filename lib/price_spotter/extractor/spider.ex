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
          cron: String.t(),
          active: boolean(),
          next_run_time: String.t() | nil,
          supports_dry_run: boolean(),
          supports_ean_override: boolean()
        }

  defstruct [
    :id,
    :name,
    :cron,
    :active,
    :next_run_time,
    :supports_dry_run,
    :supports_ean_override
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
      cron: json["cron"],
      active: json["active"],
      next_run_time: json["next_run_time"],
      supports_dry_run: json["supports_dry_run"],
      supports_ean_override: json["supports_ean_override"]
    }
  end
end
