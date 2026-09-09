defmodule PriceSpotter.Extractor.LlmClient do
  @moduledoc """
  Behaviour for the LLM that proposes EAN matches during exploration.

  The exploration flow hands the model a target product (one with no EAN) and
  a list of reference products already in the DB that share a similar name and
  *do* have an EAN. The model returns the subset of references it judges to be
  the same product - crucially, the same product at the same package
  size/unit. The exploration flow re-checks the size afterwards
  (`PriceSpotter.Extractor.PackageSize`), so the model is an aid, never the
  final authority on the weight/unit constraint.

  Concrete implementations are swapped via application config
  (`config :price_spotter, :llm, client: ...`) so tests inject a fake.
  """

  @typedoc """
  Target product handed to the model.
  """
  @type target :: %{
          required(:name) => String.t(),
          optional(:category) => String.t() | nil
        }

  @typedoc """
  A reference product the model may endorse as a match. `ean` is the value
  that comes back in a proposal's `ean_candidate`.
  """
  @type reference_product :: %{
          required(:ean) => String.t(),
          required(:name) => String.t(),
          optional(:supplier) => String.t() | nil
        }

  @typedoc """
  A single endorsement: which reference EAN the model believes matches, with
  optional confidence (0.0-1.0) and a short human-readable rationale.
  """
  @type proposal :: %{
          required(:ean_candidate) => String.t(),
          optional(:confidence) => float() | nil,
          optional(:reason) => String.t() | nil
        }

  @callback propose_matches(target(), [reference_product()], keyword()) ::
              {:ok, [proposal()]} | {:error, term()}

  @doc """
  Resolves the configured client and delegates to it.
  """
  @spec propose_matches(target(), [reference_product()], keyword()) ::
          {:ok, [proposal()]} | {:error, term()}
  def propose_matches(target, references, opts \\ []) do
    impl().propose_matches(target, references, opts)
  end

  defp impl do
    :price_spotter
    |> Application.get_env(:llm, [])
    |> Keyword.get(:client, PriceSpotter.Extractor.LlmClient.Anthropic)
  end
end
