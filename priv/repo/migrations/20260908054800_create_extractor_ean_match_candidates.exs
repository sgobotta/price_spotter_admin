defmodule PriceSpotter.Repo.Migrations.CreateExtractorEanMatchCandidates do
  use Ecto.Migration

  def change do
    # Enables trigram indexes below so the substring `ilike '%..%'` filters
    # in `PriceSpotter.Extractor.list_pending_candidate_sets/1` are indexed.
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm", ""

    create table(:extractor_ean_match_candidate_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :product_id,
          references(:products, type: :binary_id, on_delete: :delete_all),
          null: false

      add :product_name, :string, null: false
      add :category, :string
      add :status, :string, null: false, default: "pending"

      timestamps()
    end

    create unique_index(:extractor_ean_match_candidate_sets, [:product_id])

    create index(:extractor_ean_match_candidate_sets, ["product_name gin_trgm_ops"],
             using: "GIN",
             name: :extractor_ean_match_candidate_sets_product_name_trgm
           )

    create index(:extractor_ean_match_candidate_sets, ["category gin_trgm_ops"],
             using: "GIN",
             name: :extractor_ean_match_candidate_sets_category_trgm
           )

    create table(:extractor_ean_match_candidates, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :candidate_set_id,
          references(:extractor_ean_match_candidate_sets,
            type: :binary_id,
            on_delete: :delete_all
          ),
          null: false

      add :ean_candidate, :string, null: false
      add :name, :string, null: false
      add :supplier, :string, null: false
      add :url, :string
      add :image_url, :string
      add :price, :decimal
      add :last_fetched_at, :utc_datetime

      timestamps()
    end

    create index(:extractor_ean_match_candidates, [:candidate_set_id])

    create index(:extractor_ean_match_candidates, ["ean_candidate gin_trgm_ops"],
             using: "GIN",
             name: :extractor_ean_match_candidates_ean_candidate_trgm
           )

    create index(:extractor_ean_match_candidates, ["supplier gin_trgm_ops"],
             using: "GIN",
             name: :extractor_ean_match_candidates_supplier_trgm
           )

    # Decisions are a durable audit log: they outlive the pending set and,
    # via `on_delete: :nilify_all`, survive deletion of the product they
    # referenced (the denormalized product_name/supplier keep them readable).
    create table(:extractor_ean_match_decisions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :product_id,
          references(:products, type: :binary_id, on_delete: :nilify_all),
          null: true

      add :ean_candidate, :string, null: false
      add :decision, :string, null: false
      add :product_name, :string
      add :supplier, :string

      timestamps()
    end

    create index(:extractor_ean_match_decisions, [:product_id])
    create index(:extractor_ean_match_decisions, [:decision])
  end
end
