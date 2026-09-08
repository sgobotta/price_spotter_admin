defmodule PriceSpotter.Mongo.Migrator do
  @moduledoc """
  This module implements migration scripts for mongodb.
  """
  require Logger

  def migrate do
    Logger.info("Creating mongodb indexes...")
    {:ok, _} = Application.ensure_all_started(:price_spotter)

    Mongo.Ecto.create_indexes(PriceSpotter.Repos.MongoRepo, :products, [
      %{key: %{product_id: 1}, name: "product_id", unique: true}
    ])

    Mongo.Ecto.create_indexes(PriceSpotter.Repos.MongoRepo, :prices, [
      %{
        key: %{product_id: 1, timestamp: -1},
        name: "product_id_timestamp_desc"
      },
      %{key: %{timestamp: -1}, name: "timestamp_desc"}
    ])

    Logger.info("Finished creating mongodb indexes.")

    Application.stop(:price_spotter)
  end
end
