defmodule PriceSpotter.Extractor do
  @moduledoc """
  Context for managing the extractor service's spiders from the admin UI:
  listing them, editing their schedule, and triggering one-off runs with
  live progress.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias PriceSpotter.Extractor.Client
  alias PriceSpotter.Extractor.CronHumanizer
  alias PriceSpotter.Extractor.EanMatchCandidate
  alias PriceSpotter.Extractor.EanMatchCandidateSet
  alias PriceSpotter.Extractor.EanMatchDecision
  alias PriceSpotter.Extractor.RunWatcher
  alias PriceSpotter.Extractor.Spider
  alias PriceSpotter.Extractor.SpiderConfig
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotter.Repo

  @ean_lengths [8, 13, 14]

  @type ean_format_error :: %{
          ean: String.t(),
          reason: :non_numeric | :invalid_length
        }

  @type eans_config_error :: %{
          reason: :invalid_format | :not_supported,
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
  defdelegate stop_run(run_id), to: Client

  @doc """
  Persists normalized `input_config.eans` for by_ean spiders only.
  """
  @spec save_input_config(Spider.t(), String.t() | nil) ::
          {:ok, %{eans: [String.t()]}} | {:error, eans_config_error()}
  def save_input_config(%Spider{} = spider, raw_eans) do
    if Spider.ean_configurable?(spider) do
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
  Live preview of a cron expression. Returns `{:ok, text}` for valid
  expressions and `{:error, :invalid}` otherwise.
  """
  @spec preview_cron(String.t()) :: {:ok, String.t()} | {:error, :invalid}
  defdelegate preview_cron(cron), to: CronHumanizer, as: :preview

  @doc """
  Starts (linked to the caller) a process that streams a run's live
  progress into the caller as `{:extractor_run_event, run_id, message}`.
  """
  @spec watch_run(String.t(), String.t(), String.t(), pid()) ::
          {:ok, pid()} | {:error, term()}
  def watch_run(run_id, stream_url, stream_token, parent_pid \\ self()) do
    watcher().start_link(run_id, stream_url, stream_token, parent_pid)
  end

  ## EAN match candidates — pending/submitted lifecycle

  @typedoc """
  Filters for pending candidate retrieval. Any subset may be supplied.
  """
  @type candidate_filters :: %{
          optional(:name) => String.t(),
          optional(:ean_candidate) => String.t(),
          optional(:supplier) => String.t(),
          optional(:category) => String.t()
        }

  @doc """
  Inserts or replaces the pending candidate set for a product.

  Candidates are grouped by product: there is at most one pending set per
  `product_id`, and re-upserting replaces that set's candidates wholesale.
  """
  @spec upsert_candidate_set(map()) ::
          {:ok, EanMatchCandidateSet.t()} | {:error, Ecto.Changeset.t()}
  def upsert_candidate_set(attrs) do
    attrs = normalize_keys(attrs)

    case get_candidate_set_by_product(attrs["product_id"]) do
      nil -> %EanMatchCandidateSet{}
      %EanMatchCandidateSet{} = set -> Repo.preload(set, :candidates)
    end
    |> EanMatchCandidateSet.changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, set} -> {:ok, Repo.preload(set, :candidates, force: true)}
      error -> error
    end
  end

  @doc """
  Lists pending candidate sets with their candidates preloaded.

  Supported filters: `:name` and `:category` match the set's product;
  `:ean_candidate` and `:supplier` keep sets that own at least one matching
  candidate. All string filters are case-insensitive substring matches.
  """
  @spec list_pending_candidate_sets(candidate_filters()) :: [
          EanMatchCandidateSet.t()
        ]
  def list_pending_candidate_sets(filters \\ %{}) do
    filters = normalize_keys(filters)

    EanMatchCandidateSet
    |> where([s], s.status == "pending")
    |> filter_by_name(filters["name"])
    |> filter_by_category(filters["category"])
    |> filter_by_candidate(:ean_candidate, filters["ean_candidate"])
    |> filter_by_candidate(:supplier, filters["supplier"])
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
    |> Repo.preload(:candidates)
  end

  @doc """
  Fetches a pending candidate set by id with candidates preloaded.
  """
  @spec get_candidate_set!(Ecto.UUID.t()) :: EanMatchCandidateSet.t()
  def get_candidate_set!(id) do
    EanMatchCandidateSet
    |> Repo.get!(id)
    |> Repo.preload(:candidates)
  end

  @doc """
  Approves an EAN candidate for a set's product.

  In a single transaction this records an `approved` decision, applies the
  approved EAN to the related product, and removes the pending set.
  """
  @spec approve_candidate(EanMatchCandidateSet.t(), String.t()) ::
          {:ok, %{decision: EanMatchDecision.t(), product: Product.t()}}
          | {:error, :candidate_not_found | term()}
  def approve_candidate(%EanMatchCandidateSet{} = set, ean_candidate) do
    with %EanMatchCandidate{} = candidate <-
           find_candidate(set, ean_candidate) ||
             {:error, :candidate_not_found} do
      Multi.new()
      |> Multi.insert(
        :decision,
        decision_changeset(set, candidate, "approved")
      )
      |> Multi.run(:product, fn _repo, _changes ->
        apply_ean_to_product(set.product_id, candidate.ean_candidate)
      end)
      |> Multi.delete(:pending, set)
      |> Repo.transaction()
      |> case do
        {:ok, %{decision: decision, product: product}} ->
          {:ok, %{decision: decision, product: product}}

        {:error, _step, reason, _changes} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Disapproves an EAN candidate for a set's product.

  Records a `disapproved` decision and removes the pending set. The product
  is left untouched.
  """
  @spec disapprove_candidate(EanMatchCandidateSet.t(), String.t()) ::
          {:ok, %{decision: EanMatchDecision.t()}}
          | {:error, :candidate_not_found | term()}
  def disapprove_candidate(%EanMatchCandidateSet{} = set, ean_candidate) do
    with %EanMatchCandidate{} = candidate <-
           find_candidate(set, ean_candidate) ||
             {:error, :candidate_not_found} do
      Multi.new()
      |> Multi.insert(
        :decision,
        decision_changeset(set, candidate, "disapproved")
      )
      |> Multi.delete(:pending, set)
      |> Repo.transaction()
      |> case do
        {:ok, %{decision: decision}} -> {:ok, %{decision: decision}}
        {:error, _step, reason, _changes} -> {:error, reason}
      end
    end
  end

  defp get_candidate_set_by_product(nil), do: nil

  defp get_candidate_set_by_product(product_id),
    do: Repo.get_by(EanMatchCandidateSet, product_id: product_id)

  defp filter_by_name(query, nil), do: query

  defp filter_by_name(query, name),
    do: where(query, [s], ilike(s.product_name, ^"%#{name}%"))

  defp filter_by_category(query, nil), do: query

  defp filter_by_category(query, category),
    do: where(query, [s], ilike(s.category, ^"%#{category}%"))

  defp filter_by_candidate(query, _field, nil), do: query

  defp filter_by_candidate(query, field, value) do
    where(
      query,
      [s],
      s.id in subquery(
        from(c in EanMatchCandidate,
          where: ilike(field(c, ^field), ^"%#{value}%"),
          select: c.candidate_set_id
        )
      )
    )
  end

  defp find_candidate(%EanMatchCandidateSet{} = set, ean_candidate) do
    set
    |> ensure_candidates_loaded()
    |> Map.get(:candidates, [])
    |> Enum.find(&(&1.ean_candidate == ean_candidate))
  end

  defp ensure_candidates_loaded(%EanMatchCandidateSet{} = set),
    do: Repo.preload(set, :candidates)

  defp decision_changeset(set, %EanMatchCandidate{} = candidate, decision) do
    EanMatchDecision.changeset(%EanMatchDecision{}, %{
      product_id: set.product_id,
      ean_candidate: candidate.ean_candidate,
      decision: decision,
      product_name: set.product_name,
      supplier: candidate.supplier
    })
  end

  defp apply_ean_to_product(product_id, ean_candidate) do
    Product
    |> Repo.get(product_id)
    |> case do
      nil ->
        {:error, :product_not_found}

      %Product{} = product ->
        product
        |> Product.changeset(%{ean: ean_candidate})
        |> Repo.update()
    end
  end

  defp normalize_keys(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
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
        {:ok, eans}

      invalid_eans ->
        {:error,
         %{
           reason: :invalid_format,
           message: "Some EAN values have an invalid format",
           details: %{invalid_eans: invalid_eans}
         }}
    end
  end

  @spec validate_ean_formats([String.t()]) :: [ean_format_error()]
  defp validate_ean_formats(eans) do
    eans
    |> Enum.map(&classify_ean_format/1)
    |> Enum.reject(&is_nil/1)
  end

  defp classify_ean_format(ean) do
    cond do
      not String.match?(ean, ~r/^\d+$/) ->
        %{ean: ean, reason: :non_numeric}

      String.length(ean) not in @ean_lengths ->
        %{ean: ean, reason: :invalid_length}

      true ->
        nil
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
