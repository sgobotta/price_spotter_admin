defmodule PriceSpotter.Marketplaces.ProductPrice do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "product_prices" do
    field :price, :decimal
    field :timestamp, :integer
    field :product_id, :string
  end

  @doc false
  def changeset(product_price, attrs) do
    product_price
    |> cast(attrs, [
      :price,
      :timestamp,
      :product_id
    ])
    |> validate_required([
      :price,
      :timestamp,
      :product_id
    ])
  end
end
