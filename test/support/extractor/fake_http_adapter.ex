defmodule PriceSpotter.Extractor.FakeHttpAdapter do
  @moduledoc """
  Test double for `PriceSpotter.Extractor.HttpAdapter`. Call `stub/1` in a
  test to control the response the extractor client "receives" for the
  duration of that test.

  Backed by `Application.put_env/3` (not the calling process's dictionary)
  since the code under test - a LiveView - runs in its own process.
  """

  @behaviour PriceSpotter.Extractor.HttpAdapter

  @doc """
  Registers the response function used by every call to `request/4` until
  overridden. `fun` is called with `(method, url, headers, body)` and must
  return the same shape as `PriceSpotter.Extractor.HttpAdapter.request/4`.
  """
  def stub(fun) when is_function(fun, 4) do
    Application.put_env(:price_spotter, :extractor_test_stub, fun)
  end

  @impl true
  def request(method, url, headers, body) do
    case Application.get_env(:price_spotter, :extractor_test_stub) do
      nil ->
        raise "PriceSpotter.Extractor.FakeHttpAdapter.stub/1 was not called in this test"

      fun ->
        fun.(method, url, headers, body)
    end
  end
end
