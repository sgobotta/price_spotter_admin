defmodule PriceSpotter.Extractor.Run do
  @moduledoc """
  A tracked spider run as reported by the extractor service's
  `GET /admin/spiders/runs` endpoints (see `price_spotter_extractor`'s
  `docs/admin_api.md`).

  This is not persisted locally - the extractor service owns the shared
  `spider_runs` table and is the source of truth (the admin reads runs over
  the HTTP API, see `PriceSpotter.Extractor.Client`). This struct only shapes
  its JSON responses for use in the admin UI. Timestamps are kept as the raw
  ISO-8601 strings the API returns; formatting is the UI's concern.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          spider_key: String.t(),
          trigger: String.t() | nil,
          dry_run: boolean(),
          status: String.t(),
          stats: map() | nil,
          error: String.t() | nil,
          started_at: String.t() | nil,
          finished_at: String.t() | nil
        }

  defstruct [
    :id,
    :spider_key,
    :trigger,
    :dry_run,
    :status,
    :stats,
    :error,
    :started_at,
    :finished_at
  ]

  @doc """
  Builds a run struct from a decoded JSON map (a single item from any of the
  extractor service's `/admin/spiders/runs` endpoints).
  """
  @spec from_json(map()) :: t()
  def from_json(%{} = json) do
    %__MODULE__{
      id: json["id"],
      spider_key: json["spider_key"],
      trigger: json["trigger"],
      dry_run: json["dry_run"] || false,
      status: json["status"],
      stats: json["stats"],
      error: json["error"],
      started_at: json["started_at"],
      finished_at: json["finished_at"]
    }
  end

  @doc """
  True while the run is live (not yet in a terminal outcome).
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: "running"}), do: true
  def running?(_run), do: false
end
