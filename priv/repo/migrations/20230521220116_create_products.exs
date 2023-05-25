defmodule PriceSpotter.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :category, :string
      add :img_url, :string
      add :internal_id, :string
      add :supplier_name, :string
      add :meta, :map
      add :name, :string
      add :price, :decimal
      add :supplier_url, :string

      timestamps()
    end

    create unique_index(:products, [:internal_id])
  end
end
