defmodule PriceSpotter.Marketplaces.Product do
  use Ecto.Schema
  import Ecto.Changeset

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
  end
end
