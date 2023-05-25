defmodule PriceSpotter.Marketplaces.Product do
  use Ecto.Schema
  import Ecto.Changeset

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

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:category, :img_url, :internal_id, :supplier_name, :meta, :name, :price, :supplier_url])
    |> validate_required([:category, :img_url, :internal_id, :supplier_name, :name, :price, :supplier_url])
    |> unique_constraint(:internal_id)
  end

  @spec from_entry!(Redis.Stream.Entry.t()) :: Ecto.Changeset.t()
  def from_entry!(%Redis.Stream.Entry{values: product}) do
    changeset(%__MODULE__{}, Map.merge(product, %{
      "supplier_name" => product["supplier"],
      "meta" => Jason.decode!(product["meta"])
    }))
  end
end
