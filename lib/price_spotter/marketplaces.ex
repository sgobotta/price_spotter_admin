defmodule PriceSpotter.Marketplaces do
  @moduledoc """
  The Marketplaces context.
  """

  import Ecto.Query, warn: false
  alias PriceSpotter.Accounts.User
  alias PriceSpotter.Repo
  alias PriceSpotter.Repos.MongoRepo

  alias PriceSpotter.Marketplaces.{
    Product,
    ProductDocument,
    ProductPriceDocument,
    ProductPriceSnapshot,
    Relations,
    Supplier
  }

  alias Redis.Stream

  require Logger

  @type interval :: :daily | :weekly | :monthly
  @homepage_window_hours 24

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products do
    Repo.all(Product)
  end

  def list_products(params) do
    Flop.validate_and_run(Product, params, for: Product)
  end

  def list_products_by_user(params, %User{role: :admin}) do
    query = from(p in Product, select: p)

    with {:ok, flop} <- Flop.validate(params, for: Product) do
      flop = PriceSpotter.Flop.Helpers.ensure_unique_order(flop)
      {:ok, Flop.run(query, flop, for: Product)}
    end
  end

  def list_products_by_user(params, %User{} = user) do
    query =
      from(
        p in Product,
        join: s in Supplier,
        on: s.id == p.supplier_id,
        join: us in Relations.UserSupplier,
        on: us.user_id == ^user.id and s.id == us.supplier_id,
        select: p
      )

    with {:ok, flop} <- Flop.validate(params, for: Product) do
      flop = PriceSpotter.Flop.Helpers.ensure_unique_order(flop)
      {:ok, Flop.run(query, flop, for: Product)}
    end
  end

  @doc """
  Given a user, returns a list of all categories available to the user.
  Admins are not scoped by customer access and see every category.
  """
  def list_product_categories_by_user(%User{role: :admin}),
    do: list_product_categories()

  def list_product_categories_by_user(%User{} = user) do
    from(
      p in Product,
      join: s in Supplier,
      on: s.id == p.supplier_id,
      join: us in Relations.UserSupplier,
      on: us.user_id == ^user.id and s.id == us.supplier_id,
      select: p.category,
      distinct: p.category
    )
    |> Repo.all()
  end

  def list_product_categories do
    Repo.all(from(p in Product, select: p.category, distinct: p.category))
  end

  @doc """
  Returns access-scoped homepage metrics and top movers for the current user.
  """
  @spec get_homepage_metrics(User.t()) :: map()
  def get_homepage_metrics(%User{} = user) do
    since =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-@homepage_window_hours * 3600, :second)

    scoped_products_query = scoped_products_query(user)

    total_products =
      scoped_products_query
      |> subquery()
      |> Repo.aggregate(:count, :id)

    scraped_last_24h_query =
      from p in subquery(scoped_products_query),
        join: ps in ProductPriceSnapshot,
        on: ps.product_id == p.id,
        where: ps.scraped_at >= ^since,
        select: p.id,
        distinct: true

    scraped_last_24h =
      scraped_last_24h_query
      |> subquery()
      |> Repo.aggregate(:count, :id)

    movement_query = movement_query(user)

    price_increases_24h =
      movement_query
      |> where([m], m.current_price > m.previous_price)
      |> Repo.aggregate(:count, :product_id)

    price_decreases_24h =
      movement_query
      |> where([m], m.current_price < m.previous_price)
      |> Repo.aggregate(:count, :product_id)

    top_price_increase =
      movement_query
      |> where([m], m.current_price > m.previous_price)
      |> order_by([m],
        desc: fragment("? - ?", m.current_price, m.previous_price)
      )
      |> order_by([m], desc: m.current_scraped_at)
      |> limit(1)
      |> select_mover_card()
      |> Repo.one()

    top_price_decrease =
      movement_query
      |> where([m], m.current_price < m.previous_price)
      |> order_by([m],
        desc: fragment("? - ?", m.previous_price, m.current_price)
      )
      |> order_by([m], desc: m.current_scraped_at)
      |> limit(1)
      |> select_mover_card()
      |> Repo.one()

    %{
      as_of: movement_as_of_timestamp(user),
      total_products: total_products,
      products_scraped_last_24h: scraped_last_24h,
      products_price_increase_last_24h: price_increases_24h,
      products_price_decrease_last_24h: price_decreases_24h,
      top_price_increase: top_price_increase,
      top_price_decrease: top_price_decrease
    }
  end

  defp movement_query(%User{} = user) do
    since =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-@homepage_window_hours * 3600, :second)

    query =
      from p in subquery(latest_previous_pairs_query(user)),
        join: product in Product,
        on: product.id == p.product_id,
        where: p.current_scraped_at >= ^since,
        where: not is_nil(p.previous_price),
        where: p.current_price != p.previous_price,
        select: %{
          product_id: p.product_id,
          supplier_id: p.supplier_id,
          product_name: product.name,
          product_image: product.img_url,
          category_name: product.category,
          supplier_name: product.supplier_name,
          current_price: p.current_price,
          previous_price: p.previous_price,
          current_scraped_at: p.current_scraped_at
        }

    from(m in subquery(query))
  end

  defp latest_previous_pairs_query(%User{} = user) do
    ranked_query =
      from ps in ProductPriceSnapshot,
        join: p in subquery(scoped_products_query(user)),
        on: p.id == ps.product_id,
        windows: [
          pair_window: [
            partition_by: [ps.product_id, ps.supplier_id],
            order_by: [desc: ps.scraped_at, desc: ps.id]
          ]
        ],
        select: %{
          id: ps.id,
          product_id: ps.product_id,
          supplier_id: ps.supplier_id,
          price: ps.price,
          scraped_at: ps.scraped_at,
          rank: over(row_number(), :pair_window)
        }

    from r in subquery(ranked_query),
      where: r.rank <= 2,
      group_by: [r.product_id, r.supplier_id],
      select: %{
        product_id: r.product_id,
        supplier_id: r.supplier_id,
        current_price:
          max(fragment("CASE WHEN ? = 1 THEN ? END", r.rank, r.price)),
        previous_price:
          max(fragment("CASE WHEN ? = 2 THEN ? END", r.rank, r.price)),
        current_scraped_at:
          max(fragment("CASE WHEN ? = 1 THEN ? END", r.rank, r.scraped_at))
      }
  end

  defp movement_as_of_timestamp(%User{} = user) do
    from(p in subquery(latest_previous_pairs_query(user)),
      select: max(p.current_scraped_at)
    )
    |> Repo.one()
  end

  defp select_mover_card(query) do
    from m in query,
      select: %{
        product_name: m.product_name,
        product_image: m.product_image,
        supplier_name: m.supplier_name,
        category_name: m.category_name,
        current_price: m.current_price,
        absolute_delta: fragment("? - ?", m.current_price, m.previous_price),
        percentage_delta:
          fragment(
            "CASE WHEN ? = 0 THEN NULL ELSE ((? - ?) / ?) * 100 END",
            m.previous_price,
            m.current_price,
            m.previous_price,
            m.previous_price
          )
      }
  end

  defp scoped_products_query(%User{role: :admin}) do
    from(p in Product, select: %{id: p.id})
  end

  defp scoped_products_query(%User{} = user) do
    from p in Product,
      join: us in Relations.UserSupplier,
      on: us.supplier_id == p.supplier_id and us.user_id == ^user.id,
      select: %{id: p.id},
      distinct: true
  end

  @doc """
  Gets a single product.

  Raises `Ecto.NoResultsError` if the Product does not exist.

  ## Examples

      iex> get_product!(123)
      %Product{}

      iex> get_product!(456)
      ** (Ecto.NoResultsError)

  """
  def get_product!(id), do: Repo.get!(Product, id)

  @doc """
  Given an internal id returns a product if exists.

    ## Examples

      iex> get_by_internal_id("some internal id")
      %Product{}

      iex> get_by_internal_id("some internal id")
      nil

  """
  @spec get_by_internal_id(String.t()) :: Product.t()
  def get_by_internal_id(internal_id) do
    Repo.get_by(Product, internal_id: internal_id)
  end

  @doc """
  Creates a product.

  ## Examples

      iex> create_product(%{field: value})
      {:ok, %Product{}}

      iex> create_product(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_product(attrs \\ %{}) do
    %Product{}
    |> Product.changeset(attrs)
    |> Ecto.Changeset.put_change(
      :price_updated_at,
      NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    )
    |> Repo.insert()
  end

  @doc """
  Updates a product.

  ## Examples

      iex> update_product(product, %{field: new_value})
      {:ok, %Product{}}

      iex> update_product(product, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a product.

  ## Examples

      iex> delete_product(product)
      {:ok, %Product{}}

      iex> delete_product(product)
      {:error, %Ecto.Changeset{}}

  """
  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product changes.

  ## Examples

      iex> change_product(product)
      %Ecto.Changeset{data: %Product{}}

  """
  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  @doc """
  Assigns a supplier id to the given product.

  ## Examples

      iex> update_product(product, Ecto.UUID.generate())
      {:ok, %Product{}}

      iex> update_product(product, "some invalid id")
      {:error, %Ecto.Changeset{}}

  """
  def assign_supplier(%Product{} = product, supplier_id) do
    product
    |> Product.change_supplier(supplier_id)
    |> Repo.update()
  end

  # ----------------------------------------------------------------------------
  # Product cache management
  #

  @doc """
  Fetches data from redis to perform some checks before storing or updating the
  products table.
  """
  def load_product(stream_key) do
    with %Redis.Stream.Entry{id: entry_id} = entry <-
           fetch_last_product_entry(stream_key),
         %Ecto.Changeset{valid?: true} = cs <- Product.from_entry!(entry) do
      case upsert_product(cs) do
        {:ok, {:updated, p}} ->
          Logger.debug("Updated product product=#{inspect(p)}")
          # Trace updated product
          {:ok, p, entry_id}

        {:ok, {:created, p}} ->
          Logger.debug("Created product product=#{inspect(p)}")
          # Trace new added product
          {:ok, p, entry_id}
      end
    else
      %Ecto.Changeset{valid?: false} = cs ->
        Logger.error(
          "An error occured while casting stream values into Product changeset=#{inspect(cs)}"
        )

        {:error, :invalid_values}

      error ->
        error
    end
  end

  @doc """
  Atomically inserts or updates a product record whether an entity is persisted
  or not. Then a Supplier existance is checked to finally relate the product to
  the resulting supplier.
  """
  @spec upsert_product(Ecto.Changeset.t()) :: any()
  def upsert_product(cs) do
    internal_id = Ecto.Changeset.get_field(cs, :internal_id)

    Ecto.Multi.new()
    # Checks product existance
    |> Ecto.Multi.one(:product, fn _multi ->
      from(p in Product, where: p.internal_id == ^internal_id)
    end)
    # Create or Update product
    |> Ecto.Multi.run(:maybe_create_product, fn
      _repo, %{product: nil} = _multi ->
        Logger.debug(
          "Detected new product, creating new entry with internal_id=#{internal_id}"
        )

        cs =
          Ecto.Changeset.put_change(
            cs,
            :price_updated_at,
            NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
          )

        {:ok, %Product{} = p} = create_product(cs.changes)

        Logger.debug(
          "Created new product with product_id=#{p.id} product=#{inspect(p)}"
        )

        {:ok, {:created, p}}

      _repo, %{product: %Product{} = product} = _multi ->
        maybe_update_product = fn product, %Ecto.Changeset{} = changeset ->
          maybe_price_change =
            Ecto.Changeset.get_change(changeset, :price, product.price)

          %Ecto.Changeset{} =
            changeset =
            if product.price == maybe_price_change do
              Logger.debug(
                "Price did not change. Skipping price update for product_id=#{product.id} product=#{inspect(product)}"
              )

              changeset
            else
              Logger.debug(
                "Detected price change. Updating product with id=#{product.id} with price from old_price=#{inspect(product.price)} to new_price=#{inspect(maybe_price_change)}"
              )

              Ecto.Changeset.put_change(
                changeset,
                :price_updated_at,
                NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
              )
            end

          {:ok, %Product{} = updated_product} =
            update_product(product, changeset.changes)

          Logger.debug(
            "Updated product with product_id=#{updated_product.id} product=#{inspect(updated_product)}"
          )

          updated_product
        end

        %Product{} = maybe_updated_product = maybe_update_product.(product, cs)

        {:ok, {:updated, maybe_updated_product}}
    end)
    # Check supplier existance
    |> Ecto.Multi.one(:supplier, fn %{
                                      maybe_create_product:
                                        {product_op,
                                         %Product{supplier_name: supplier_name}}
                                    }
                                    when product_op in [:created, :updated] ->
      from(s in Supplier, where: s.name == ^supplier_name)
    end)
    # Create or update Supplier
    |> Ecto.Multi.run(:maybe_create_supplier, fn
      _repo,
      %{
        maybe_create_product:
          {_product_op, %Product{supplier_name: supplier_name}},
        supplier: nil
      } ->
        {:ok, %Supplier{} = s} = create_supplier(%{name: supplier_name})
        {:ok, {:created, s}}

      _repo, %{supplier: %Supplier{} = s} ->
        {:ok, {:noop, s}}
    end)
    # Relate supplier to a product
    |> Ecto.Multi.run(:assoc_supplier, fn _repo,
                                          %{
                                            maybe_create_product:
                                              {_product_op, %Product{} = p},
                                            maybe_create_supplier:
                                              {_supplier_op,
                                               %Supplier{id: supplier_id}}
                                          } ->
      {:ok, %Product{}} = assign_supplier(p, supplier_id)
      {:ok, {:ok, :noop}}
    end)
    # Submit transaction
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        {:ok, result.maybe_create_product}

      error ->
        Logger.error(
          "There was an error while processing a product upsert error=#{inspect(error, pretty: true)}"
        )

        error
    end
  end

  # ----------------------------------------------------------------------------
  # Cache queries
  #

  @spec fetch_last_product_entry(binary, non_neg_integer() | String.t()) ::
          Redis.Stream.Entry.t() | list() | any()
  def fetch_last_product_entry(stream_key, _count \\ "*") do
    product_stream_key = "product-history_" <> stream_key
    stream_name = get_stream_name(product_stream_key)

    case Redis.Client.fetch_last_stream_entry(stream_name) do
      {:ok, %Redis.Stream.Entry{} = entry} ->
        entry

      error ->
        Logger.error(
          "An error occured while fetching last product entry from redis for stream_key=#{stream_name}."
        )

        error
    end
  end

  @doc """
  Given a supplier name and an internal id for a product, returns a list of
  redis stream entries for all the avaialble historical data.
  """
  @spec fetch_product_history(String.t(), String.t(), atom()) ::
          {:ok, [Redis.Stream.Entry.t()]} | :error
  def fetch_product_history(supplier_name, internal_id, interval \\ :daily) do
    stream_name =
      get_stream_name("product-history_" <> supplier_name <> "_" <> internal_id)

    before_now = look_into_the_past(-20, interval)

    since =
      DateTime.utc_now()
      |> DateTime.add(before_now, :day)
      |> DateTime.to_unix(:millisecond)

    with {:ok, entries} <-
           Redis.Client.fetch_reverse_stream_since(stream_name, since),
         filtered_entries <- filter_history_entries(entries, interval),
         history <- map_product_history(filtered_entries) do
      {:ok, history}
    else
      error ->
        Logger.error(
          "An error occured while fetching product history from redis for supplier_name=#{supplier_name} internal_id=#{internal_id} error=#{inspect(error)}"
        )

        :error
    end
  rescue
    error ->
      Logger.error(
        "Recovered from an while fetching product history from redis error=#{inspect(error)}"
      )

      :error
  end

  @doc """
  Given a supplier name and an internal id for a product, returns a list of
  product prices.
  """
  @spec fetch_prices_history(String.t(), atom()) ::
          {:ok, [{NaiveDateTime.t(), ProductDocument.t()}]} | :error
  def fetch_prices_history(product_id, interval \\ :daily) do
    before_now = look_into_the_past(-20, interval)

    since =
      DateTime.utc_now()
      |> DateTime.add(before_now, :day)
      |> DateTime.to_unix(:millisecond)

    case get_product_document_by_id(product_id) do
      %ProductDocument{id: id} ->
        query =
          from ppd in ProductPriceDocument,
            where: ppd.product_id == ^id and ppd.timestamp > ^since

        prices =
          MongoRepo.stream(query)
          |> Enum.to_list()
          |> filter_history_prices(interval)
          |> map_price_history()

        {:ok, prices}

      nil ->
        Logger.error(
          "An error occured while fetching product history from collection product_id=#{product_id}."
        )

        :error
    end
  end

  @spec look_into_the_past(integer(), atom()) :: integer()
  defp look_into_the_past(days, :daily), do: days
  defp look_into_the_past(days, :monthly), do: days * 30
  defp look_into_the_past(days, :weekly), do: days * 7

  @deprecated "Use filter_history_prices"
  @spec filter_history_entries([Redis.Stream.Entry.t()], atom()) :: [
          Redis.Stream.Entry.t()
        ]
  defp filter_history_entries(entries, interval) do
    entries
    |> group_history_by(interval)
    |> Enum.map(fn {_datetime, entries} ->
      entries
      |> Enum.sort_by(
        &DateTime.to_date(Stream.Entry.get_datetime(&1)),
        {:desc, Date}
      )
      |> hd()
    end)
    |> Enum.sort_by(
      &DateTime.to_date(Stream.Entry.get_datetime(&1)),
      {:asc, Date}
    )
  end

  @spec filter_history_prices([ProductPriceDocument.t()], atom()) :: [
          ProductPriceDocument.t()
        ]
  defp filter_history_prices(prices, interval) do
    prices
    |> group_prices_history_by(interval)
    |> Enum.map(fn {_datetime, entries} ->
      entries
      |> Enum.sort_by(& &1.timestamp, :desc)
      |> hd()
    end)
    |> Enum.sort_by(& &1.timestamp, :asc)
  end

  @deprecated "Use group_prices_history_by"
  @spec group_history_by([Redis.Stream.Entry.t()], interval()) :: map()
  defp group_history_by(entries, :daily) do
    entries
    |> Enum.group_by(&DateTime.to_date(Stream.Entry.get_datetime(&1)))
  end

  defp group_history_by(entries, :monthly) do
    entries
    |> Enum.group_by(fn %Stream.Entry{} = entry ->
      Stream.Entry.get_datetime(entry)
      |> DateTime.to_date()
      |> Date.beginning_of_month()
    end)
  end

  defp group_history_by(entries, :weekly) do
    entries
    |> Enum.group_by(fn %Stream.Entry{} = entry ->
      Stream.Entry.get_datetime(entry)
      |> DateTime.to_date()
      |> Date.beginning_of_week()
    end)
  end

  @deprecated "Use map_price_history"
  @spec map_product_history([Redis.Stream.Entry.t()]) :: [
          {NaiveDateTime.t(), Product.t()}
        ]
  defp map_product_history(entries) do
    Enum.map(entries, fn %Redis.Stream.Entry{datetime: datetime} = entry ->
      %Product{} =
        product =
        entry
        |> Product.from_entry!()
        |> Ecto.Changeset.apply_changes()

      {datetime, product}
    end)
  end

  @spec group_prices_history_by([ProductPriceDocument.t()], interval()) :: map()
  defp group_prices_history_by(prices, :daily) do
    prices
    |> Enum.group_by(&DateTime.to_date(ProductPriceDocument.get_datetime(&1)))
  end

  defp group_prices_history_by(prices, :weekly) do
    prices
    |> Enum.group_by(
      &(DateTime.to_date(ProductPriceDocument.get_datetime(&1))
        |> Date.beginning_of_week())
    )
  end

  defp group_prices_history_by(prices, :monthly) do
    prices
    |> Enum.group_by(
      &(DateTime.to_date(ProductPriceDocument.get_datetime(&1))
        |> Date.beginning_of_month())
    )
  end

  @spec map_price_history([ProductPriceDocument.t()]) :: [
          {NaiveDateTime.t(), ProductPriceDocument.t()}
        ]
  defp map_price_history(prices) do
    Enum.map(prices, fn %ProductPriceDocument{timestamp: timestamp} =
                          product_price_document ->
      {DateTime.from_unix!(timestamp, :millisecond), product_price_document}
    end)
  end

  defp get_stream_name(stream_key), do: "#{get_stage()}_stream_#{stream_key}_v1"

  defp get_stage, do: PriceSpotter.Application.stage()

  # ----------------------------------------------------------------------------
  # Products collection operations
  #

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking product document changes.

  ## Examples

      iex> change_product_price_document(%ProductDocument{}, %{
        price: Decimal.new("240.02), timestamp: :os.system_time()
      })
      %Ecto.Changeset{data: %ProductDocument{}}

  """
  @spec change_product_price_document(map()) :: Ecto.Changeset.t()
  def change_product_price_document(attrs) do
    ProductPriceDocument.changeset(%ProductPriceDocument{}, attrs)
  end

  @spec create_product_document_price(map()) ::
          {:ok, ProductPriceDocument.t()} | {:error, Ecto.Changeset.t()}
  def create_product_document_price(attrs) do
    attrs
    |> change_product_price_document()
    |> MongoRepo.insert()
  end

  @doc """
  Gets a single product document or nil .

  ## Examples

      iex> get_product_document_by_id("15521ec8-88bd-438c-b6fc-e6f956cae824")
      %ProductDocument{}

      iex> get_product_document_by_id!("48ad0f71-33d0-42d8-a6dc-f3f5c530b9aa")
      nil

  """
  @spec get_product_document_by_id(Ecto.UUID.t()) :: ProductDocument.t() | nil
  def get_product_document_by_id(product_id),
    do: MongoRepo.get_by(ProductDocument, product_id: product_id)

  @doc """
  Creates a product document or raises.

  ## Examples

      iex> create_product_document("15521ec8-88bd-438c-b6fc-e6f956cae824")
      %ProductDocument{}

  """
  @spec create_product_document(Ecto.UUID.t()) :: ProductDocument.t()
  def create_product_document(product_id) do
    %ProductDocument{}
    |> ProductDocument.changeset(%{product_id: product_id})
    |> MongoRepo.insert!()
  end

  @doc """
  Records a price for a `ProductDocument`.

  ## Examples

      iex> record_product_price(%ProductPrice{
        id: "dd5987f0-8d0a-4d08-bd37-c0dabc7a8bf6",
        price: Decimal.new("240.05")
      }, 1748226064)
      {:ok, %ProductDocument{}}

      iex> record_product_price(%ProductDocument{}, 1748226064)
      {:error, %Ecto.Changeset{}}

  """
  @spec record_product_price(Product.t(), non_neg_integer()) ::
          {:ok, ProductPriceDocument.t()} | {:error, Ecto.Changeset.t()}
  def record_product_price(
        %Product{id: product_id, price: price, supplier_id: supplier_id},
        timestamp \\ :os.system_time(:millisecond)
      ) do
    get_or_create = fn product_id ->
      case get_product_document_by_id(product_id) do
        nil ->
          {:ok, create_product_document(product_id)}

        %ProductDocument{} = pd ->
          {:ok, pd}
      end
    end

    {:ok, %ProductDocument{id: product_document_id}} =
      get_or_create.(product_id)

    with {:ok, %ProductPriceDocument{} = price_document} <-
           create_product_document_price(%{
             product_id: product_document_id,
             price: price,
             timestamp: timestamp
           }),
         {:ok, _snapshot} <-
           create_product_price_snapshot(%{
             product_id: product_id,
             supplier_id: supplier_id,
             price: price,
             scraped_at:
               DateTime.from_unix!(timestamp, :millisecond)
               |> DateTime.to_naive()
           }) do
      {:ok, price_document}
    end

    # case get_or_create.(product_id) do
    #   {:ok, %ProductDocument{id: product_document_id}} ->
    #     create_product_document_price(%{
    #       product_id: product_document_id,
    #       price: price,
    #       timestamp: timestamp
    #     })

    #   %Ecto.Changeset{valid?: false} = cs ->
    #     {:error, cs}
    # end
  end

  @spec create_product_price_snapshot(map()) ::
          {:ok, ProductPriceSnapshot.t()} | {:error, Ecto.Changeset.t()}
  def create_product_price_snapshot(attrs) do
    %ProductPriceSnapshot{}
    |> ProductPriceSnapshot.changeset(attrs)
    |> Repo.insert()
  end

  # ----------------------------------------------------------------------------
  # Suppliers API
  #

  @doc """
  Returns the list of suppliers.

  ## Examples

      iex> list_suppliers()
      [%Supplier{}, ...]

  """
  def list_suppliers do
    Repo.all(Supplier)
  end

  @doc """
  Returns a Flop-paginated list of suppliers for the admin index page.
  """
  def list_suppliers(params) do
    with {:ok, flop} <- Flop.validate(params, for: Supplier) do
      flop = PriceSpotter.Flop.Helpers.ensure_unique_order(flop)
      {:ok, Flop.run(Supplier, flop, for: Supplier)}
    end
  end

  @doc """
  Given a user, returns a list of suppliers the user has access to.
  """
  @spec list_suppliers_by_user(User.t()) :: [String.t()]
  def list_suppliers_by_user(%User{role: :admin}) do
    list_suppliers()
    |> Enum.map(& &1.name)
    |> Enum.uniq()
  end

  def list_suppliers_by_user(%User{} = user) do
    from(
      s in Supplier,
      join: us in Relations.UserSupplier,
      on: s.id == us.supplier_id,
      where: us.user_id == ^user.id,
      select: s.name,
      distinct: s.name
    )
    |> Repo.all()
  end

  @doc """
  Gets a single supplier.

  Raises `Ecto.NoResultsError` if the Supplier does not exist.

  ## Examples

      iex> get_supplier!(123)
      %Supplier{}

      iex> get_supplier!(456)
      ** (Ecto.NoResultsError)

  """
  def get_supplier!(id), do: Repo.get!(Supplier, id)

  @doc """
  Creates a supplier.

  ## Examples

      iex> create_supplier(%{field: value})
      {:ok, %Supplier{}}

      iex> create_supplier(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_supplier(attrs \\ %{}) do
    %Supplier{}
    |> Supplier.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a supplier.

  ## Examples

      iex> update_supplier(supplier, %{field: new_value})
      {:ok, %Supplier{}}

      iex> update_supplier(supplier, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_supplier(%Supplier{} = supplier, attrs) do
    supplier
    |> Supplier.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a supplier.

  ## Examples

      iex> delete_supplier(supplier)
      {:ok, %Supplier{}}

      iex> delete_supplier(supplier)
      {:error, %Ecto.Changeset{}}

  """
  def delete_supplier(%Supplier{} = supplier) do
    Repo.delete(supplier)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking supplier changes.

  ## Examples

      iex> change_supplier(supplier)
      %Ecto.Changeset{data: %Supplier{}}

  """
  def change_supplier(%Supplier{} = supplier, attrs \\ %{}) do
    Supplier.changeset(supplier, attrs)
  end

  alias PriceSpotter.Marketplaces.Relations.UserSupplier

  @doc """
  Returns the list of supplier access grants for a given user, preloaded
  with their supplier.
  """
  def list_user_suppliers_for_user(%User{} = user) do
    from(us in UserSupplier, where: us.user_id == ^user.id, preload: [:supplier])
    |> Repo.all()
  end

  @doc """
  Returns a Flop-paginated list of user-suppliers for the admin index page,
  with the `:user` and `:supplier` associations preloaded.
  """
  def list_users_suppliers(params) do
    query = from(us in UserSupplier, preload: [:user, :supplier])

    with {:ok, flop} <- Flop.validate(params, for: UserSupplier) do
      flop = PriceSpotter.Flop.Helpers.ensure_unique_order(flop)
      {:ok, Flop.run(query, flop, for: UserSupplier)}
    end
  end

  @doc """
  Gets a single user_supplier.

  Raises `Ecto.NoResultsError` if the User supplier does not exist.

  ## Examples

      iex> get_user_supplier!(123)
      %UserSupplier{}

      iex> get_user_supplier!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_supplier!(id), do: Repo.get!(UserSupplier, id)

  @doc """
  Creates a user_supplier.

  ## Examples

      iex> create_user_supplier(%{field: value})
      {:ok, %UserSupplier{}}

      iex> create_user_supplier(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_supplier(attrs \\ %{}) do
    %UserSupplier{}
    |> UserSupplier.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_supplier.

  ## Examples

      iex> update_user_supplier(user_supplier, %{field: new_value})
      {:ok, %UserSupplier{}}

      iex> update_user_supplier(user_supplier, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_supplier(%UserSupplier{} = user_supplier, attrs) do
    user_supplier
    |> UserSupplier.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_supplier.

  ## Examples

      iex> delete_user_supplier(user_supplier)
      {:ok, %UserSupplier{}}

      iex> delete_user_supplier(user_supplier)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_supplier(%UserSupplier{} = user_supplier) do
    Repo.delete(user_supplier)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_supplier changes.

  ## Examples

      iex> change_user_supplier(user_supplier)
      %Ecto.Changeset{data: %UserSupplier{}}

  """
  def change_user_supplier(%UserSupplier{} = user_supplier, attrs \\ %{}) do
    UserSupplier.changeset(user_supplier, attrs)
  end

  @doc """
  Inserts one UserSupplier row per `%{supplier_id:, role:}` entry for the
  given user, in a single transaction. All-or-nothing: if any row fails
  validation (bad enum value, duplicate supplier already granted), the whole
  batch rolls back and the failing row's index + changeset are returned so
  the caller can flag just that row and let the admin fix and resubmit —
  acceptable since this is a low-volume admin form (a handful of rows at a
  time).
  """
  @spec create_user_suppliers(User.t(), [map()]) ::
          {:ok, [UserSupplier.t()]} | {:error, integer(), Ecto.Changeset.t()}
  def create_user_suppliers(%User{} = user, attrs_list)
      when is_list(attrs_list) do
    attrs_list
    |> Enum.uniq_by(& &1.supplier_id)
    |> Enum.with_index()
    |> Enum.reduce(Ecto.Multi.new(), fn {attrs, index}, multi ->
      changeset =
        UserSupplier.changeset(
          %UserSupplier{},
          Map.put(attrs, :user_id, user.id)
        )

      Ecto.Multi.insert(multi, {:user_supplier, index}, changeset)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, results} ->
        user_suppliers =
          results
          |> Enum.sort_by(fn {{:user_supplier, index}, _user_supplier} ->
            index
          end)
          |> Enum.map(fn {_key, user_supplier} -> user_supplier end)

        {:ok, user_suppliers}

      {:error, {:user_supplier, index}, changeset, _changes_so_far} ->
        {:error, index, changeset}
    end
  end
end
