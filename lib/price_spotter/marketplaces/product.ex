defmodule PriceSpotter.Marketplaces.Product do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :category, :internal_id, :supplier_name, :price, :price_updated_at],
    sortable: [:name, :category, :internal_id, :supplier_name, :price],
    custom_fields: [
      price_updated_at: [
        filter: {PriceSpotter.Marketplaces.Product.CustomFilters, :price_updated_at, []},
        ecto_type: :naive_datetime
      ]
    ],
    default_limit: 10
  }

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "products" do
    field :category, :string
    field :img_url, :string
    field :internal_id, :string
    field :meta, :map
    field :name, :string
    field :price, :decimal
    field :supplier_name, :string
    field :supplier_url, :string
    field :price_updated_at, :naive_datetime

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
      :price_updated_at
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

  @spec sanitize_price(String.t()) :: String.t()
  defp sanitize_price(nil), do: 0

  defp sanitize_price(price) do
    if String.length(price) > 3 do
      String.replace(price, ".", "")
    else
      price
    end
  end
end

defmodule PriceSpotter.Marketplaces.Product.CustomFilters do
  @moduledoc false
  import Ecto.Query

  @spec price_updated_at(PriceSpotter.Marketplaces.Product.t(), Flop.Filter.t(), keyword()) ::
          Ecto.Query.t()
  def price_updated_at(q, %Flop.Filter{value: value, op: op}, _options) do
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
end
