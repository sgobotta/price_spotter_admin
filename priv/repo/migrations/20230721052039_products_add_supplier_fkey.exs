defmodule PriceSpotter.Repo.Migrations.ProductsAddSupplierFkey do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :supplier_id, references(:suppliers, type: :binary_id)
    end
  end
end
