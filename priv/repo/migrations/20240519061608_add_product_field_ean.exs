defmodule PriceSpotter.Repo.Migrations.AddProductFieldEan do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :ean, :string, default: nil
    end
  end
end
