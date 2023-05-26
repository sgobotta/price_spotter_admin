defmodule PriceSpotter.Repo.Migrations.AddProductFieldPriceUpdatedAt do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :price_updated_at, :naive_datetime
    end
  end
end
