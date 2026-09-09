defmodule PriceSpotter.Extractor.EanMatchDecision do
  @moduledoc """
  A committed admin decision about an EAN match candidate. This is the
  durable record of what was approved or disapproved; the pending set that
  produced it is removed once the decision is written.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PriceSpotter.Marketplaces.Product

  @type t :: %__MODULE__{}

  @decisions ~w(approved disapproved)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extractor_ean_match_decisions" do
    field :ean_candidate, :string
    field :decision, :string
    field :product_name, :string
    field :supplier, :string

    belongs_to :product, Product

    timestamps()
  end

  @doc false
  def changeset(decision, attrs) do
    decision
    |> cast(attrs, [
      :product_id,
      :ean_candidate,
      :decision,
      :product_name,
      :supplier
    ])
    |> validate_required([:product_id, :ean_candidate, :decision])
    |> validate_inclusion(:decision, @decisions)
  end

  @spec decisions() :: [String.t()]
  def decisions, do: @decisions
end
