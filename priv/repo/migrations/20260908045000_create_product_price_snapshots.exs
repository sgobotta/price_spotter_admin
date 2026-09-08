defmodule PriceSpotter.Repo.Migrations.CreateProductPriceSnapshots do
  use Ecto.Migration

  def change do
    create table(:product_price_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :product_id, references(:products, type: :binary_id, on_delete: :delete_all),
        null: false

      add :supplier_id, references(:suppliers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :price, :decimal, null: false
      add :scraped_at, :naive_datetime, null: false

      timestamps(updated_at: false)
    end

    create index(:product_price_snapshots, [:product_id, :supplier_id, :scraped_at, :id],
             name: :product_price_snapshots_pair_scraped_at_id_idx
           )

    create index(:product_price_snapshots, [:scraped_at, :product_id, :supplier_id],
             name: :product_price_snapshots_scraped_at_product_supplier_idx
           )

    create index(:products, [:supplier_id])
    create index(:users_suppliers, [:supplier_id, :user_id])
  end
end
