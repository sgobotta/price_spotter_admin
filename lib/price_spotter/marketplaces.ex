defmodule PriceSpotter.Marketplaces do
  @moduledoc """
  The Marketplaces context.
  """

  import Ecto.Query, warn: false
  alias PriceSpotter.Repo

  alias PriceSpotter.Marketplaces.Product

  require Logger

  @doc """
  Returns the list of products.

  ## Examples

      iex> list_products()
      [%Product{}, ...]

  """
  def list_products do
    Repo.all(Product)
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

  # ----------------------------------------------------------------------------
  # Product cache management
  #

  @doc """
  Fetches data from redis to perform some checks before storing or updating the
  products table.
  """
  def load_product(stream_key) do
    with %Redis.Stream.Entry{} = entry <- fetch_last_product_entry(stream_key),
         %Ecto.Changeset{valid?: true} = cs <- Product.from_entry!(entry) do
      case upsert_product(cs) do
        {:ok, {:updated, p}} ->
          # Trace updated product
          {:ok, p}

        {:ok, {:created, p}} ->
          # Trace new added product
          {:ok, p}
      end

    else
      %Ecto.Changeset{valid?: false} = cs ->
        Logger.error("An error occured while casting stream values into Product changeset=#{inspect(cs)}")
        {:error, :invalid_values}

      error ->
        error
    end
  end

  @doc """
  Atomically inserts or updates a product record whether an entity is persisted
  or not.
  """
  @spec upsert_product(Ecto.Changeset.t()) :: any()
  def upsert_product(cs) do
    internal_id = cs.changes.internal_id
    Ecto.Multi.new()
    |> Ecto.Multi.one(:product, fn _multi ->
      from(p in Product, where: p.internal_id == ^internal_id)
    end)
    |> Ecto.Multi.run(:op, fn
      _repo, %{product: nil} = _multi ->
        {:ok, %Product{} = p} = create_product(cs.changes)
        {:ok, {:created, p}}

      _repo, %{product: product} = _multi ->
        {:ok, %Product{} = p} = update_product(product, cs.changes)
        {:ok, {:updated, p}}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, result} ->
        {:ok, result.op}

      error ->
        Logger.error("There was an error while processing a product upsert error=#{inspect(error, pretty: true)}")
        error

    end
  end

  @spec fetch_last_product_entry(binary, non_neg_integer() | String.t()) :: {:ok, any()} | {:error, :no_product}
  def fetch_last_product_entry(stream_key, _count \\ "*") do
    stream_name = get_stream_name("product-history_" <> stream_key)

    with {:ok, %Redis.Stream.Entry{} = entry} <- Redis.Client.fetch_last_stream_entry(stream_name) do
      entry

    else
      {:error, :no_product} ->
        []

      error ->
        Logger.error("An error occured while fetching product history results from redis.")
        error

    end
  end

  defp get_stream_name(stream_key), do: "#{get_env()}_stream_#{stream_key}_v1"

  defp get_env, do: Atom.to_string(Mix.env())
end
