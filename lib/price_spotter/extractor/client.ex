defmodule PriceSpotter.Extractor.Client do
  @moduledoc """
  HTTP client for the extractor service's admin API (see
  `price_spotter_extractor`'s `docs/admin_api.md`): listing spiders, editing
  their schedule and runtime params, and triggering one-off runs.
  """

  require Logger

  alias PriceSpotter.Extractor.Run
  alias PriceSpotter.Extractor.Spider

  @type error :: %{status: pos_integer() | nil, message: String.t()}

  @typedoc """
  Identifiers needed to open the run-stream WebSocket for a run.
  """
  @type stream_ref :: %{
          run_id: String.t(),
          stream_token: String.t(),
          stream_url: String.t()
        }

  @typedoc """
  Filters for `list_runs/1`. Any subset may be supplied; omitted keys are
  not sent, letting the extractor apply its defaults.
  """
  @type run_filters :: [
          status: :running | :finished | String.t(),
          spider: String.t(),
          limit: pos_integer()
        ]

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
  Merges a runtime-params overlay onto the spider's class defaults.
  Pass `nil` to clear the overlay (all keys back to class defaults).
  """
  @spec update_params(String.t(), map() | nil) ::
          {:ok, Spider.t()} | {:error, error()}
  def update_params(key, params) do
    :patch
    |> request("/admin/spiders/#{key}/params", %{params: params})
    |> handle_response(&Spider.from_json/1)
  end

  @doc """
  Triggers a single, immediate run of the given spider. Pass `dry_run:
  true` to run without persisting anything, and/or `eans: [...]` to run
  against that exact list instead of the spider's configured source -
  both only valid when the spider supports them
  (`Spider.supports_dry_run`/`supports_ean_override`). `params` is a
  per-run overlay on stored runtime params; omit when empty.
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
      |> maybe_put_params(Keyword.get(opts, :params))

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

  @doc """
  Requests an in-flight run to stop.
  """
  @spec stop_run(String.t()) :: {:ok, map()} | {:error, error()}
  def stop_run(run_id) do
    :post
    |> request("/admin/spiders/runs/#{run_id}/stop", %{})
    |> handle_response(fn body -> body || %{} end)
  end

  @doc """
  Lists tracked runs, most-recent first, over the extractor HTTP API (the
  source of truth). Optional filters: `:status` (`:running` | `:finished`),
  `:spider` (a spider key) and `:limit`. Omitted filters are not sent, so the
  extractor applies its own defaults (both running and finished, limit 50).
  """
  @spec list_runs(run_filters()) :: {:ok, [Run.t()]} | {:error, error()}
  def list_runs(filters \\ []) do
    :get
    |> request("/admin/spiders/runs" <> runs_query(filters))
    |> handle_response(fn body -> Enum.map(body, &Run.from_json/1) end)
  end

  @doc """
  Fetches a single run's metadata and outcome by `run_id`.
  """
  @spec get_run(String.t()) :: {:ok, Run.t()} | {:error, error()}
  def get_run(run_id) do
    :get
    |> request("/admin/spiders/runs/#{run_id}")
    |> handle_response(&Run.from_json/1)
  end

  @doc """
  Fetches a run's full buffered structured progress log as a list of frame
  maps, oldest first - the same frames delivered live over the WebSocket.
  Returns `{:ok, []}` once the extractor's log retention has expired. Frames
  are kept as decoded maps; the UI renders them.
  """
  @spec get_run_logs(String.t()) :: {:ok, [map()]} | {:error, error()}
  def get_run_logs(run_id) do
    :get
    |> request("/admin/spiders/runs/#{run_id}/logs")
    |> handle_response(fn body -> body || [] end)
  end

  @doc """
  Mints a fresh stream token for any `run_id`, so the browser can open the
  run-stream WebSocket for a run this session did not start (a scheduled/cron
  run, or one started elsewhere). Returns the identifiers needed to open the
  stream.
  """
  @spec create_stream_token(String.t()) ::
          {:ok, stream_ref()} | {:error, error()}
  def create_stream_token(run_id) do
    :post
    |> request("/admin/spiders/runs/#{run_id}/stream-token", %{})
    |> handle_response(fn body ->
      %{
        run_id: body["run_id"],
        stream_token: body["stream_token"],
        stream_url: body["stream_url"]
      }
    end)
  end

  defp runs_query(filters) do
    case filters
         |> Keyword.take([:status, :spider, :limit])
         |> Enum.reject(fn {_key, value} -> is_nil(value) end)
         |> Enum.map(fn {key, value} -> {key, to_string(value)} end) do
      [] -> ""
      params -> "?" <> URI.encode_query(params)
    end
  end

  defp maybe_put_eans(body, eans) when eans in [nil, []], do: body
  defp maybe_put_eans(body, eans), do: Map.put(body, :eans, eans)

  defp maybe_put_params(body, params) when params in [nil, %{}], do: body
  defp maybe_put_params(body, params), do: Map.put(body, :params, params)

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
