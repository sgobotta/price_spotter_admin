defmodule PriceSpotter.Extractor.Exploration do
  @moduledoc """
  Scheduled and per-product EAN exploration.

  Finds products with no EAN, gathers same-name reference products that *do*
  have an EAN, asks the LLM which references are the same product, and - after
  re-enforcing the package size/unit hard constraint
  (`PriceSpotter.Extractor.PackageSize`) - upserts the survivors as a pending
  match-candidate set (`PriceSpotter.Extractor.upsert_candidate_set/1`) for
  admin review.

  Every run is recorded as a `PriceSpotter.Extractor.ExplorationRun` with
  structured logs and aggregate stats. `run_monthly/1` is the scheduled
  entrypoint; `run_for_product/2` handles a single manual exploration.
  """

  import Ecto.Query, warn: false

  require Logger

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Client
  alias PriceSpotter.Extractor.ExplorationRun
  alias PriceSpotter.Extractor.LlmClient
  alias PriceSpotter.Extractor.PackageSize
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotter.Repo

  @default_reference_limit 25
  @default_similarity 0.3

  @typedoc """
  Options accepted by the run entrypoints.

    * `:limit` - cap the number of no-EAN products scanned (scheduled run).
    * `:reference_limit` - max reference products per target (default 25).
    * `:similarity` - trigram similarity threshold, 0.0-1.0 (default 0.3).
    * `:fetch_prices` - when `true`, request a fresh extractor price fetch
      for the endorsed EANs (best-effort; results flow back through the
      normal ingestion path, not this run).
  """
  @type run_opts :: keyword()

  @doc """
  Scheduled monthly entrypoint: explore every product that has no EAN.
  """
  @spec run_monthly(run_opts()) ::
          {:ok, ExplorationRun.t()} | {:error, term()}
  def run_monthly(opts \\ []) do
    products = list_products_without_ean(opts)
    do_run("scheduled", nil, products, opts)
  end

  @doc """
  Manual per-product entrypoint used by the admin controls.
  """
  @spec run_for_product(Product.t() | Ecto.UUID.t(), run_opts()) ::
          {:ok, ExplorationRun.t()} | {:error, :product_not_found | term()}
  def run_for_product(%Product{} = product, opts) do
    do_run("manual", product, [product], opts)
  end

  def run_for_product(product_id, opts) when is_binary(product_id) do
    case Repo.get(Product, product_id) do
      nil -> {:error, :product_not_found}
      %Product{} = product -> run_for_product(product, opts)
    end
  end

  @doc """
  Products that still need an EAN (null or empty), most recently updated
  first. Honors an optional `:limit`.
  """
  @spec list_products_without_ean(run_opts()) :: [Product.t()]
  def list_products_without_ean(opts \\ []) do
    Product
    |> where([p], is_nil(p.ean) or p.ean == "")
    |> order_by([p], desc: p.updated_at)
    |> maybe_limit(opts[:limit])
    |> Repo.all()
  end

  @doc """
  Reference products that share a similar name with `product` and already
  carry an EAN, ranked by trigram similarity.
  """
  @spec find_reference_products(Product.t(), run_opts()) :: [Product.t()]
  def find_reference_products(%Product{} = product, opts \\ []) do
    threshold = opts[:similarity] || @default_similarity
    limit = opts[:reference_limit] || @default_reference_limit
    name = product.name || ""

    Product
    |> where([p], p.id != ^product.id)
    |> where([p], not is_nil(p.ean) and p.ean != "")
    |> where([p], fragment("similarity(?, ?) > ?", p.name, ^name, ^threshold))
    |> order_by([p], desc: fragment("similarity(?, ?)", p.name, ^name))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Explores a single product: collects references, gets LLM endorsements,
  enforces the size/unit constraint, and upserts the surviving candidates.

  Returns a result summary map, or `{:ok, :no_references}` /
  `{:ok, :no_candidates}` when there is nothing to propose.
  """
  @spec explore_product(Product.t(), run_opts()) ::
          {:ok, map()}
          | {:ok, :no_references | :no_candidates}
          | {:error, term()}
  def explore_product(%Product{} = product, opts \\ []) do
    case find_reference_products(product, opts) do
      [] ->
        {:ok, :no_references}

      references ->
        with {:ok, proposals} <- request_proposals(product, references) do
          finalize_candidates(product, references, proposals, opts)
        end
    end
  end

  ## Internal

  defp request_proposals(product, references) do
    target = %{name: product.name, category: product.category}

    refs =
      Enum.map(references, fn ref ->
        %{ean: ref.ean, name: ref.name, supplier: ref.supplier_name}
      end)

    LlmClient.propose_matches(target, refs)
  end

  defp finalize_candidates(product, references, proposals, opts) do
    endorsed =
      proposals
      |> Enum.map(& &1.ean_candidate)
      |> MapSet.new()

    proposed_count = MapSet.size(endorsed)

    # Hard weight/unit safeguard: keep only endorsed references whose package
    # size is compatible with the target, regardless of what the LLM said.
    kept =
      references
      |> Enum.filter(fn ref ->
        MapSet.member?(endorsed, ref.ean) and
          PackageSize.compatible?(product.name, ref.name)
      end)
      |> Enum.uniq_by(& &1.ean)

    size_rejections = max(proposed_count - length(kept), 0)

    case kept do
      [] ->
        {:ok, :no_candidates}

      candidates ->
        maybe_fetch_prices(candidates, opts)

        with {:ok, set} <- upsert(product, candidates) do
          {:ok,
           %{
             set: set,
             candidate_count: length(candidates),
             proposed_count: proposed_count,
             size_rejections: size_rejections
           }}
        end
    end
  end

  defp upsert(product, candidates) do
    Extractor.upsert_candidate_set(%{
      product_id: product.id,
      product_name: product.name,
      category: product.category,
      candidates: Enum.map(candidates, &candidate_attrs/1)
    })
  end

  defp candidate_attrs(%Product{} = ref) do
    %{
      ean_candidate: ref.ean,
      name: ref.name,
      supplier: ref.supplier_name,
      url: ref.supplier_url,
      image_url: ref.img_url,
      price: ref.price,
      last_fetched_at: to_utc(ref.price_updated_at)
    }
  end

  defp to_utc(nil), do: nil

  defp to_utc(%NaiveDateTime{} = naive) do
    naive
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.truncate(:second)
  end

  # Best-effort extractor price refresh. Never blocks or fails the run: the
  # extractor persists fresh prices through the usual ingestion path, so this
  # only kicks off the fetch and logs the outcome.
  defp maybe_fetch_prices(candidates, opts) do
    if opts[:fetch_prices] do
      eans = Enum.map(candidates, & &1.ean)

      case Client.trigger_run("coto-by-ean", eans: eans) do
        {:ok, _run} ->
          :ok

        {:error, reason} ->
          Logger.warning("Exploration price fetch failed: #{inspect(reason)}")
          :ok
      end
    else
      :ok
    end
  end

  defp do_run(trigger, product, products, opts) do
    case start_run(trigger, product) do
      {:ok, run} ->
        run_and_record(run, products, opts)

      {:error, changeset} ->
        Logger.error("Could not start exploration run: #{inspect(changeset)}")
        {:error, changeset}
    end
  end

  defp run_and_record(run, products, opts) do
    {logs, stats} = explore_all(products, opts)
    complete_run(run, logs, stats)
  rescue
    error ->
      message = Exception.message(error)
      Logger.error("Exploration run crashed: #{message}")
      fail_run(run, message)
      {:error, error}
  end

  defp explore_all(products, opts) do
    initial = {
      [ExplorationRun.log_entry(:info, "Exploration started")],
      %{scanned: 0, sets: 0, candidates: 0}
    }

    {logs, stats} =
      Enum.reduce(products, initial, fn product, {logs, stats} ->
        {entry, delta} = explore_one(product, opts)
        {[entry | logs], merge_stats(stats, delta)}
      end)

    summary =
      ExplorationRun.log_entry(:info, "Exploration finished", %{
        "products_scanned" => stats.scanned,
        "candidate_sets_upserted" => stats.sets,
        "candidates_proposed" => stats.candidates
      })

    {Enum.reverse([summary | logs]), stats}
  end

  defp explore_one(product, opts) do
    case explore_product(product, opts) do
      {:ok, :no_references} ->
        {log(product, "No reference products found", :info),
         %{scanned: 1, sets: 0, candidates: 0}}

      {:ok, :no_candidates} ->
        {log(product, "No size-compatible candidates", :info),
         %{scanned: 1, sets: 0, candidates: 0}}

      {:ok, result} ->
        {log(product, candidate_message(result), :info),
         %{scanned: 1, sets: 1, candidates: result.candidate_count}}

      {:error, reason} ->
        {log(product, "Exploration error: #{inspect(reason)}", :error),
         %{scanned: 1, sets: 0, candidates: 0}}
    end
  end

  defp candidate_message(result) do
    "Upserted #{result.candidate_count} candidate(s); " <>
      "#{result.size_rejections} dropped for size/unit mismatch"
  end

  defp log(product, message, level) do
    ExplorationRun.log_entry(level, message, %{
      "product_id" => product.id,
      "product_name" => product.name
    })
  end

  defp merge_stats(a, b) do
    %{
      scanned: a.scanned + b.scanned,
      sets: a.sets + b.sets,
      candidates: a.candidates + b.candidates
    }
  end

  defp start_run(trigger, product) do
    %ExplorationRun{}
    |> ExplorationRun.changeset(%{
      trigger: trigger,
      status: "running",
      product_id: product && product.id,
      started_at: now()
    })
    |> Repo.insert()
  end

  defp complete_run(run, logs, stats) do
    run
    |> ExplorationRun.changeset(%{
      status: "completed",
      logs: logs,
      products_scanned: stats.scanned,
      candidate_sets_upserted: stats.sets,
      candidates_proposed: stats.candidates,
      finished_at: now()
    })
    |> Repo.update()
  end

  defp fail_run(run, message) do
    run
    |> ExplorationRun.changeset(%{
      status: "failed",
      error: message,
      finished_at: now()
    })
    |> Repo.update()
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp maybe_limit(query, nil), do: query

  defp maybe_limit(query, limit) when is_integer(limit),
    do: limit(query, ^limit)
end
