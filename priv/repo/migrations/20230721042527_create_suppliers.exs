defmodule PriceSpotter.Repo.Migrations.CreateSuppliers do
  use Ecto.Migration

  def change do
    create table(:suppliers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string

      add :products, references(:products, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create unique_index(:suppliers, [:name])
  end
end
