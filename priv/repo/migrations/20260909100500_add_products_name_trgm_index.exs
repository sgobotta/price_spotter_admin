defmodule PriceSpotter.Repo.Migrations.AddProductsNameTrgmIndex do
  use Ecto.Migration

  # GIN trigram index so the EAN exploration's reference lookup
  # (`PriceSpotter.Extractor.Exploration.find_reference_products/2`) can use
  # the pg_trgm `%` similarity operator on products.name instead of a full
  # scan during the monthly run. pg_trgm is already enabled by the
  # extractor_ean_match_candidates migration.
  def change do
    create index(:products, ["name gin_trgm_ops"],
             using: "GIN",
             name: :products_name_trgm
           )
  end
end
