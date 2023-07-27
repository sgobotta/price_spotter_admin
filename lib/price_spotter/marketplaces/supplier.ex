defmodule PriceSpotter.Marketplaces.Supplier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "suppliers" do
    field :name, :string

    has_many :products, PriceSpotter.Marketplaces.Product

    many_to_many :users, PriceSpotter.Accounts.User,
      join_through: PriceSpotter.Marketplaces.Relations.UserSupplier,
      on_replace: :delete,
      on_delete: :delete_all,
      unique: true

    timestamps()
  end

  @doc false
  def changeset(supplier, attrs) do
    supplier
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
