defmodule PriceSpotter.Extractor.HttpAdapter.Httpc do
  @moduledoc """
  Default `PriceSpotter.Extractor.HttpAdapter` implementation, built on
  Erlang's built-in `:httpc` (part of `:inets`) so this client needs no
  extra HTTP dependency.
  """

  @behaviour PriceSpotter.Extractor.HttpAdapter

  @impl true
  def request(method, url, headers, body) do
    charlist_headers =
      Enum.map(headers, fn {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}
      end)

    http_request =
      case body do
        nil ->
          {String.to_charlist(url), charlist_headers}

        body ->
          {String.to_charlist(url), charlist_headers, ~c"application/json",
           body}
      end

    case :httpc.request(method, http_request, [timeout: 15_000],
           body_format: :binary
         ) do
      {:ok, {{_version, status, _reason}, _headers, resp_body}} ->
        {:ok, status, decode(resp_body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode(""), do: nil
  defp decode(body), do: Jason.decode!(body)
end
