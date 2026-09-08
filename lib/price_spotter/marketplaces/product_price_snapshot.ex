defmodule PriceSpotter.Marketplaces.ProductPriceSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias PriceSpotter.Marketplaces.{Product, Supplier}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "product_price_snapshots" do
    field :price, :decimal
    field :scraped_at, :naive_datetime

    belongs_to :product, Product
    belongs_to :supplier, Supplier

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:price, :scraped_at, :product_id, :supplier_id])
    |> validate_required([:price, :scraped_at, :product_id, :supplier_id])
  end
end
