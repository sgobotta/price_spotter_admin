defmodule PriceSpotter.Marketplaces.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @max_limit 10_000
  @default_limit 10

  @derive {
    Flop.Schema,
    filterable: [
      :name,
      :category,
      :internal_id,
      :supplier_name,
      :price_updated_since,
      :min_price,
      :max_price
    ],
    sortable: [
      :name,
      :category,
      :internal_id,
      :supplier_name,
      :price,
      :price_updated_at
    ],
    custom_fields: [
      price_updated_since: [
        filter:
          {PriceSpotter.Marketplaces.Product.CustomFilters,
           :price_updated_since, []},
        ecto_type: :naive_datetime
      ],
      max_price: [
        filter: {PriceSpotter.Marketplaces.Product.CustomFilters, :price, []},
        ecto_type: :decimal
      ],
      min_price: [
        filter: {PriceSpotter.Marketplaces.Product.CustomFilters, :price, []},
        ecto_type: :decimal
      ]
    ],
    default_limit: @default_limit,
    max_limit: @max_limit
  }

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :category, :string
    field :img_url, :string
    field :internal_id, :string
    field :meta, :map, default: %{}
    field :name, :string
    field :price, :decimal
    field :supplier_name, :string
    field :supplier_url, :string
    field :price_updated_at, :naive_datetime

    belongs_to :supplier, PriceSpotter.Marketplaces.Supplier

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :category,
      :img_url,
      :internal_id,
      :supplier_name,
      :meta,
      :name,
      :price,
      :supplier_url,
      :price_updated_at,
      :supplier_id
    ])
    |> validate_required([
      :category,
      :img_url,
      :internal_id,
      :supplier_name,
      :name,
      :price,
      :supplier_url
    ])
    |> unique_constraint(:internal_id)
  end

  def change_supplier(product, supplier_id) do
    product
    |> cast(%{supplier_id: supplier_id}, [:supplier_id])
    |> validate_required([:supplier_id])
  end

  @spec from_entry!(Redis.Stream.Entry.t()) :: Ecto.Changeset.t()
  def from_entry!(%Redis.Stream.Entry{values: product}) do
    changeset(
      %__MODULE__{},
      Map.merge(product, %{
        "supplier_name" => product["supplier"],
        "meta" => Jason.decode!(product["meta"]),
        "price" => sanitize_price(product["price"])
      })
    )
  end

  @spec max_limit() :: non_neg_integer()
  def max_limit, do: @max_limit

  @spec limit() :: non_neg_integer()
  def limit, do: @default_limit

  @spec sanitize_price(String.t()) :: String.t()
  defp sanitize_price(nil), do: 0

  defp sanitize_price("unpriced"), do: 0

  defp sanitize_price(price), do: price
end

defmodule PriceSpotter.Marketplaces.Product.CustomFilters do
  @moduledoc false
  import Ecto.Query

  alias PriceSpotter.Marketplaces.Product

  @spec price_updated_since(Product.t(), Flop.Filter.t(), keyword()) ::
          Ecto.Query.t()
  def price_updated_since(q, %Flop.Filter{value: value, op: op}, _options) do
    case Ecto.Type.cast(:naive_datetime, value) do
      {:ok, since_date} ->
        case op do
          :== -> where(q, [p], p.price_updated_at == ^since_date)
          :!= -> where(q, [p], p.price_updated_at != ^since_date)
          :> -> where(q, [p], p.price_updated_at > ^since_date)
          :< -> where(q, [p], p.price_updated_at < ^since_date)
          :>= -> where(q, [p], p.price_updated_at >= ^since_date)
          :<= -> where(q, [p], p.price_updated_at <= ^since_date)
        end

      :error ->
        # cannot cast filter value, ignore
        q
    end
  end

  @spec price(Product.t(), Flop.Filter.t(), keyword()) :: Ecto.Query.t()
  def price(q, %Flop.Filter{value: value, op: :<=}, _options) do
    case Ecto.Type.cast(:decimal, value) do
      {:ok, price} ->
        where(q, [p], p.price <= ^price)

      :error ->
        # cannot cast filter value, ignore
        q
    end
  end

  def price(q, %Flop.Filter{value: value, op: :>=}, _options) do
    case Ecto.Type.cast(:decimal, value) do
      {:ok, price} ->
        where(q, [p], p.price >= ^price)

      :error ->
        # cannot cast filter value, ignore
        q
    end
  end
end
