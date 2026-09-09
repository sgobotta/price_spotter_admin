defmodule PriceSpotter.Extractor.EanMatchCandidate do
  @moduledoc """
  A single EAN match candidate: one piece of evidence proposing an EAN for
  the parent set's product. Carries the evidence surfaced to the admin
  reviewer (name, supplier, url, image, price, last fetched at).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias PriceSpotter.Extractor.EanMatchCandidateSet

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extractor_ean_match_candidates" do
    field :ean_candidate, :string
    field :name, :string
    field :supplier, :string
    field :url, :string
    field :image_url, :string
    field :price, :decimal
    field :last_fetched_at, :utc_datetime

    belongs_to :candidate_set, EanMatchCandidateSet

    timestamps()
  end

  @doc false
  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [
      :ean_candidate,
      :name,
      :supplier,
      :url,
      :image_url,
      :price,
      :last_fetched_at
    ])
    |> validate_required([:ean_candidate, :name, :supplier])
  end
end
