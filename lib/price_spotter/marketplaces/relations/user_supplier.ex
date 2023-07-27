defmodule PriceSpotter.Marketplaces.Relations.UserSupplier do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [:role]
  @foreign_fields [:user_id, :supplier_id]

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users_suppliers" do
    field :role, Ecto.Enum, values: [:maintainer, :consumer]

    belongs_to :user, PriceSpotter.Accounts.User
    belongs_to :supplier, PriceSpotter.Marketplaces.Supplier

    timestamps()
  end

  @doc false
  def changeset(user_supplier, attrs) do
    user_supplier
    |> cast(attrs, @fields ++ @foreign_fields)
    |> cast_assoc(:user)
    |> cast_assoc(:supplier)
    |> validate_required(@fields ++ @foreign_fields)
    |> unique_constraint([:user_id, :supplier_id])
  end
end
