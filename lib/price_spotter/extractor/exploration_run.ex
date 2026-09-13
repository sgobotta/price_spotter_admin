defmodule PriceSpotter.Extractor.ExplorationRun do
  @moduledoc """
  Execution record for an EAN match-candidate exploration.

  One row is created per exploration - the monthly scheduled job or a
  per-product manual run - and carries the structured, append-only log lines
  and the aggregate stats the admin review UI surfaces. Mirrors the job/log
  shape used by earlier extractor features.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PriceSpotter.Marketplaces.Product

  @type t :: %__MODULE__{}

  @triggers ~w(scheduled manual)
  @statuses ~w(running completed failed)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extractor_exploration_runs" do
    field :trigger, :string, default: "scheduled"
    field :status, :string, default: "running"
    field :products_scanned, :integer, default: 0
    field :candidate_sets_upserted, :integer, default: 0
    field :candidates_proposed, :integer, default: 0
    field :logs, {:array, :map}, default: []
    field :error, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    belongs_to :product, Product

    timestamps()
  end

  @doc false
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :trigger,
      :status,
      :product_id,
      :products_scanned,
      :candidate_sets_upserted,
      :candidates_proposed,
      :logs,
      :error,
      :started_at,
      :finished_at
    ])
    |> validate_required([:trigger, :status, :started_at])
    |> validate_inclusion(:trigger, @triggers)
    |> validate_inclusion(:status, @statuses)
  end

  @doc """
  Builds a single structured log entry with an ISO-8601 UTC timestamp.
  """
  @spec log_entry(atom() | String.t(), String.t(), map()) :: map()
  def log_entry(level, message, meta \\ %{}) do
    at =
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()

    %{
      "level" => to_string(level),
      "message" => message,
      "meta" => meta,
      "at" => at
    }
  end
end
