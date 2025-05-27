defmodule PriceSpotter.Marketplaces.ProductDocument do
  alias PriceSpotter.Marketplaces.ProductPriceDocument
  use Ecto.Schema

  import Ecto.Changeset

  require Logger

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "products" do
    field :product_id, :string
    embeds_many :prices, PriceSpotter.Marketplaces.ProductPriceDocument
  end

  @doc false
  def changeset(product_document, attrs) do
    product_document
    |> cast(attrs, [
      :product_id
    ])
    |> validate_required([
      :product_id
    ])
  end

  @spec record_price_changeset(t(), map()) :: Ecto.Changeset.t()
  def record_price_changeset(
        %PriceSpotter.Marketplaces.ProductDocument{prices: prices} =
          product_document,
        product_price_attrs
      ) do
    case ProductPriceDocument.changeset(product_price_attrs) do
      %Ecto.Changeset{valid?: true} = ppd_cs ->
        product_document
        |> Ecto.Changeset.change(%{prices: prices ++ [ppd_cs]})

      %Ecto.Changeset{valid?: false} ->
        Logger.error(
          "Error while validating price to record: invalid `product_price_attrs` value, attrs=#{product_price_attrs}"
        )

        change(product_document)
        |> add_error(:prices, "Invalid price provided")
    end
  end
end

defmodule PriceSpotter.Marketplaces.ProductPriceDocument do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  embedded_schema do
    field :price, :decimal
    field :timestamp, :integer
  end

  def changeset(attrs) do
    %PriceSpotter.Marketplaces.ProductPriceDocument{}
    |> cast(attrs, [:price, :timestamp])
    |> validate_required([:price, :timestamp])
  end
end
