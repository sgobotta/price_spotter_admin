defmodule PriceSpotter.Extractor.FakeLlmClient do
  @moduledoc """
  Test double for `PriceSpotter.Extractor.LlmClient`. Call `stub/1` in a test
  to control what the exploration flow "receives" from the model.

  Two stub shapes are supported:

    * a function `(target, references, opts) -> {:ok, [proposal]} | {:error, _}`
    * the atom `:endorse_all`, which endorses every reference EAN - handy for
      exercising the size/unit safeguard, since the fake deliberately does not
      apply it.

  Backed by `Application.put_env/3` so it survives across processes.
  """
  @behaviour PriceSpotter.Extractor.LlmClient

  @key :llm_test_stub

  @doc """
  Registers the stub used by every `propose_matches/3` call until overridden.
  """
  @spec stub(
          (map(), [map()], keyword() -> {:ok, [map()]} | {:error, term()})
          | :endorse_all
        ) ::
          :ok
  def stub(fun_or_mode) do
    Application.put_env(:price_spotter, @key, fun_or_mode)
  end

  @impl true
  def propose_matches(target, references, opts) do
    case Application.get_env(:price_spotter, @key) do
      nil ->
        raise "PriceSpotter.Extractor.FakeLlmClient.stub/1 was not called"

      :endorse_all ->
        {:ok, endorse_all(references)}

      fun when is_function(fun, 3) ->
        fun.(target, references, opts)
    end
  end

  defp endorse_all(references) do
    Enum.map(references, fn ref ->
      %{ean_candidate: ref.ean, confidence: 1.0, reason: "fake endorsement"}
    end)
  end
end
