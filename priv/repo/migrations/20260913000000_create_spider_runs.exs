defmodule PriceSpotter.Repo.Migrations.CreateSpiderRuns do
  use Ecto.Migration

  @moduledoc """
  Mirrors the shared `spider_runs` table owned by the extractor service
  (price_spotter_extractor's `storage/postgres.py`), so the shared schema is
  represented in the admin repo - the same rationale as `spider_schedules`.

  The admin app reads runs over the extractor HTTP API (source of truth), not
  from this table directly, so there is no matching Ecto schema. The extractor
  creates the table lazily with `CREATE TABLE IF NOT EXISTS` on first use;
  `create_if_not_exists` here keeps whichever service migrates first from
  clashing with the other. Column types mirror the extractor's DDL: `TEXT`,
  `JSONB`, `TIMESTAMP` (naive), `UUID` primary key supplied by the caller
  (no default).
  """

  def change do
    create_if_not_exists table(:spider_runs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :spider_key, :text, null: false
      add :trigger, :text, null: false
      add :dry_run, :boolean, null: false, default: false
      add :status, :text, null: false
      add :stats, :map
      add :error, :text
      add :started_at, :naive_datetime, null: false, default: fragment("NOW()")
      add :finished_at, :naive_datetime
    end
  end
end
