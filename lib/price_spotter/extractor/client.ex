defmodule PriceSpotter.Extractor.Client do
  @moduledoc """
  HTTP client for the extractor service's admin API (see
  `price_spotter_extractor`'s `docs/admin_api.md`): listing spiders, editing
  their schedule, and triggering one-off runs.
  """

  require Logger

  alias PriceSpotter.Extractor.Spider

  @type error :: %{status: pos_integer() | nil, message: String.t()}

  @doc """
  Lists every spider registered in the extractor service.
  """
  @spec list_spiders() :: {:ok, [Spider.t()]} | {:error, error()}
  def list_spiders do
    :get
    |> request("/admin/spiders")
    |> handle_response(fn body -> Enum.map(body, &Spider.from_json/1) end)
  end

  @doc """
  Edits a spider's cron expression and/or whether it's active. `attrs` may
  contain `:cron` and/or `:active` - only the keys present are sent, per the
  extractor API accepting either field alone or both together.
  """
  @spec update_schedule(String.t(), %{
          optional(:cron) => String.t(),
          optional(:active) => boolean()
        }) :: {:ok, Spider.t()} | {:error, error()}
  def update_schedule(key, attrs) do
    body = Map.take(attrs, [:cron, :active])

    :patch
    |> request("/admin/spiders/#{key}/schedule", body)
    |> handle_response(&Spider.from_json/1)
  end

  @doc """
  Triggers a single, immediate run of the given spider. Pass `dry_run:
  true` to run without persisting anything, and/or `eans: [...]` to run
  against that exact list instead of the spider's configured source -
  both only valid when the spider supports them
  (`Spider.supports_dry_run`/`supports_ean_override`).
  """
  @spec trigger_run(String.t(), keyword()) ::
          {:ok,
           %{
             run_id: String.t(),
             stream_token: String.t(),
             stream_url: String.t()
           }}
          | {:error, error()}
  def trigger_run(key, opts \\ []) do
    body =
      %{dry_run: Keyword.get(opts, :dry_run, false)}
      |> maybe_put_eans(Keyword.get(opts, :eans))

    :post
    |> request("/admin/spiders/#{key}/run", body)
    |> handle_response(fn body ->
      %{
        run_id: body["run_id"],
        stream_token: body["stream_token"],
        stream_url: body["stream_url"]
      }
    end)
  end

  defp maybe_put_eans(body, eans) when eans in [nil, []], do: body
  defp maybe_put_eans(body, eans), do: Map.put(body, :eans, eans)

  defp request(method, path), do: do_request(method, path, nil)

  defp request(method, path, body),
    do: do_request(method, path, Jason.encode!(body))

  defp do_request(method, path, body) do
    config = config()
    url = config[:base_url] <> path
    headers = [{"x-admin-token", config[:api_token]}]

    adapter().request(method, url, headers, body)
  end

  defp adapter,
    do: config()[:adapter] || PriceSpotter.Extractor.HttpAdapter.Httpc

  defp config, do: Application.fetch_env!(:price_spotter, :extractor)

  defp handle_response({:ok, status, body}, on_success)
       when status in 200..299 do
    {:ok, on_success.(body)}
  end

  defp handle_response({:ok, status, body}, _on_success) do
    Logger.error(
      "Extractor API returned an error: status=#{status} body=#{inspect(body)}"
    )

    {:error, %{status: status, message: error_message(body, status)}}
  end

  defp handle_response({:error, reason}, _on_success) do
    Logger.error("Extractor API request failed: #{inspect(reason)}")
    {:error, %{status: nil, message: "Could not reach the extractor service"}}
  end

  defp error_message(%{"error" => message}, _status) when is_binary(message),
    do: message

  defp error_message(_body, status),
    do: "Unexpected response (status #{status})"
end
