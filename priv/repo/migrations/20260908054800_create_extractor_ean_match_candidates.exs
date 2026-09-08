defmodule PriceSpotter.Repo.Migrations.CreateExtractorEanMatchCandidates do
  use Ecto.Migration

  def change do
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
    create index(:extractor_ean_match_candidate_sets, [:product_name])
    create index(:extractor_ean_match_candidate_sets, [:category])

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
    create index(:extractor_ean_match_candidates, [:ean_candidate])
    create index(:extractor_ean_match_candidates, [:supplier])

    create table(:extractor_ean_match_decisions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :product_id,
          references(:products, type: :binary_id, on_delete: :delete_all),
          null: false

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
