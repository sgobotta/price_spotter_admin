defmodule PriceSpotter.Extractor.HttpAdapter do
  @moduledoc """
  Behaviour for performing the extractor client's HTTP requests, so tests
  can swap in a fake instead of hitting the network.
  """

  @callback request(
              method :: :get | :patch | :post,
              url :: String.t(),
              headers :: [{String.t(), String.t()}],
              body :: iodata() | nil
            ) :: {:ok, non_neg_integer(), term()} | {:error, term()}
end
