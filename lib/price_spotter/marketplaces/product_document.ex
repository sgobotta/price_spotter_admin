defmodule PriceSpotter.Marketplaces.ProductDocument do
  use Ecto.Schema

  alias PriceSpotter.Marketplaces.ProductPriceDocument

  import Ecto.Changeset

  require Logger

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "products" do
    field :product_id, :string

    has_many :prices, ProductPriceDocument, foreign_key: :product_id
  end

  @doc false
  def changeset(product_document, attrs) do
    product_document
    |> cast(attrs, [:product_id])
    |> validate_required([:product_id])
    |> unique_constraint(:product_id)
  end
end

defmodule PriceSpotter.Marketplaces.ProductPriceDocument do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "prices" do
    field :price, :decimal
    field :timestamp, :integer

    belongs_to :product, PriceSpotter.Marketplaces.ProductDocument,
      type: :string
  end

  def changeset(%__MODULE__{} = product_price_document, attrs) do
    product_price_document
    |> cast(attrs, [:price, :timestamp, :product_id])
    |> validate_required([:price, :timestamp, :product_id])
  end

  @spec get_datetime(t()) :: DateTime.t()
  def get_datetime(%__MODULE__{timestamp: timestamp}),
    do: DateTime.from_unix!(timestamp, :millisecond)
end
