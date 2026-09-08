defmodule PriceSpotter.Extractor.EanMatchCandidateSet do
  @moduledoc """
  A pending set of EAN match candidates grouped by product.

  One set exists per product while its matches await an admin decision.
  Submitting a decision removes the set from this pending store; the
  decision itself is recorded separately in
  `PriceSpotter.Extractor.EanMatchDecision`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PriceSpotter.Extractor.EanMatchCandidate
  alias PriceSpotter.Marketplaces.Product

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extractor_ean_match_candidate_sets" do
    field :product_name, :string
    field :category, :string
    field :status, :string, default: "pending"

    belongs_to :product, Product

    has_many :candidates, EanMatchCandidate,
      foreign_key: :candidate_set_id,
      on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(candidate_set, attrs) do
    candidate_set
    |> cast(attrs, [:product_id, :product_name, :category, :status])
    |> validate_required([:product_id, :product_name])
    |> cast_assoc(:candidates)
    |> unique_constraint(:product_id)
  end
end
