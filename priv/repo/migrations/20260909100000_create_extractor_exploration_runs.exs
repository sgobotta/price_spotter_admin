defmodule PriceSpotter.Repo.Migrations.CreateExtractorExplorationRuns do
  use Ecto.Migration

  def change do
    create table(:extractor_exploration_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # "scheduled" (monthly job) or "manual" (per-product exploration).
      add :trigger, :string, null: false, default: "scheduled"
      # "running" | "completed" | "failed".
      add :status, :string, null: false, default: "running"

      # Set only for a per-product manual exploration. Nilified if the
      # product is later deleted so the run record survives as a log.
      add :product_id,
          references(:products, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :products_scanned, :integer, null: false, default: 0
      add :candidate_sets_upserted, :integer, null: false, default: 0
      add :candidates_proposed, :integer, null: false, default: 0

      # Structured, append-only execution log lines surfaced by the admin UI.
      add :logs, {:array, :map}, null: false, default: []
      add :error, :text

      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime

      timestamps()
    end

    create index(:extractor_exploration_runs, [:status])
    create index(:extractor_exploration_runs, [:trigger])
    create index(:extractor_exploration_runs, [:product_id])
    create index(:extractor_exploration_runs, [:started_at])
  end
end
