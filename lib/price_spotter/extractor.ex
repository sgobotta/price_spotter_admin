defmodule PriceSpotter.Extractor do
  @moduledoc """
  Context for managing the extractor service's spiders from the admin UI:
  listing them, editing their schedule, and triggering one-off runs with
  live progress.
  """

  import Ecto.Query, warn: false

  alias PriceSpotter.Extractor.Client
  alias PriceSpotter.Extractor.CronHumanizer
  alias PriceSpotter.Extractor.RunWatcher
  alias PriceSpotter.Extractor.Spider
  alias PriceSpotter.Extractor.SpiderConfig
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotter.Repo

  @ean_lengths [8, 13, 14]
  @batch_size 500

  @type eans_config_error :: %{
          reason: :invalid_format | :unknown_eans | :not_supported,
          message: String.t(),
          details: map()
        }

  @spec list_spiders() :: {:ok, [Spider.t()]} | {:error, Client.error()}
  def list_spiders do
    with {:ok, spiders} <- Client.list_spiders() do
      {:ok, with_local_input_config(spiders)}
    end
  end

  defdelegate update_schedule(key, attrs), to: Client
  defdelegate trigger_run(key, opts \\ []), to: Client

  @doc """
  Persists normalized `input_config.eans` for by_ean spiders only.
  """
  @spec save_input_config(Spider.t(), String.t() | nil) ::
          {:ok, %{eans: [String.t()]}} | {:error, eans_config_error()}
  def save_input_config(%Spider{} = spider, raw_eans) do
    if spider.type == "by_ean" do
      with {:ok, eans} <- normalize_and_validate_eans(raw_eans),
           {:ok, _config} <-
             upsert_spider_config(spider.name, %{"eans" => eans}) do
        {:ok, %{eans: eans}}
      end
    else
      {:error,
       %{
         reason: :not_supported,
         message: "This extractor does not support EAN input configuration",
         details: %{}
       }}
    end
  end

  @spec parse_eans(String.t() | nil) :: [String.t()]
  def parse_eans(raw) when raw in [nil, ""], do: []

  def parse_eans(raw) do
    raw
    |> String.split(~r/[\r\n,]+/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> dedupe_preserving_order()
  end

  @doc """
  Human-readable summary of a cron expression, falling back to the raw
  string when it doesn't match a recognized pattern.
  """
  @spec humanize_cron(String.t()) :: String.t()
  defdelegate humanize_cron(cron), to: CronHumanizer, as: :humanize

  @doc """
  Starts (linked to the caller) a process that streams a run's live
  progress into the caller as `{:extractor_run_event, run_id, message}`.
  """
  @spec watch_run(String.t(), String.t(), String.t(), pid()) ::
          {:ok, pid()} | {:error, term()}
  def watch_run(run_id, stream_url, stream_token, parent_pid \\ self()) do
    watcher().start_link(run_id, stream_url, stream_token, parent_pid)
  end

  defp watcher,
    do:
      Application.fetch_env!(:price_spotter, :extractor)[:watcher] || RunWatcher

  defp with_local_input_config(spiders) do
    spider_names = Enum.map(spiders, & &1.name)

    configs_by_name =
      from(sc in SpiderConfig,
        where: sc.spider_name in ^spider_names,
        select: {sc.spider_name, sc.input_config}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(spiders, fn spider ->
      local_config = Map.get(configs_by_name, spider.name, %{})
      merged_config = Map.merge(spider.input_config || %{}, local_config)
      %Spider{spider | input_config: merged_config}
    end)
  end

  defp upsert_spider_config(spider_name, input_config) do
    attrs = %{spider_name: spider_name, input_config: input_config}

    %SpiderConfig{}
    |> SpiderConfig.changeset(attrs)
    |> Repo.insert(
      on_conflict: [
        set: [input_config: input_config, updated_at: NaiveDateTime.utc_now()]
      ],
      conflict_target: :spider_name
    )
  end

  defp normalize_and_validate_eans(raw_eans) do
    eans = parse_eans(raw_eans)

    case validate_ean_formats(eans) do
      [] ->
        validate_known_eans(eans)

      invalid_eans ->
        {:error,
         %{
           reason: :invalid_format,
           message: "Some EAN values have an invalid format",
           details: %{invalid_eans: invalid_eans}
         }}
    end
  end

  defp validate_ean_formats(eans) do
    Enum.filter(eans, fn ean ->
      not String.match?(ean, ~r/^\d+$/) or
        String.length(ean) not in @ean_lengths
    end)
  end

  defp validate_known_eans(eans) do
    known_eans =
      eans
      |> Enum.chunk_every(@batch_size)
      |> Enum.flat_map(fn batch ->
        from(p in Product,
          where: p.ean in ^batch and not is_nil(p.ean),
          select: p.ean,
          distinct: true
        )
        |> Repo.all()
      end)
      |> MapSet.new()

    unknown_eans = Enum.reject(eans, &MapSet.member?(known_eans, &1))

    if unknown_eans == [] do
      {:ok, eans}
    else
      {:error,
       %{
         reason: :unknown_eans,
         message: "Some EAN values are unknown",
         details: %{unknown_eans: unknown_eans}
       }}
    end
  end

  defp dedupe_preserving_order(values) do
    {_seen, unique} =
      Enum.reduce(values, {MapSet.new(), []}, fn value, {seen, acc} ->
        if MapSet.member?(seen, value) do
          {seen, acc}
        else
          {MapSet.put(seen, value), [value | acc]}
        end
      end)

    Enum.reverse(unique)
  end
end
