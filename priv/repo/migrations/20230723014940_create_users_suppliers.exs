defmodule PriceSpotter.Repo.Migrations.CreateUsersSuppliers do
  use Ecto.Migration

  def change do
    create table(:users_suppliers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "consumer"
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :supplier_id, references(:suppliers, on_delete: :nothing, type: :binary_id)

      timestamps()
    end

    create unique_index(:users_suppliers, [:user_id, :supplier_id])
  end
end
