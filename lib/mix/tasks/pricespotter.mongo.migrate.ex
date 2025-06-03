defmodule Mix.Tasks.PriceSpotter.Mongo.Migrate do
  @moduledoc """
  This module is responsible of defining a task that helps developers run mongo
  migrations.

  This is a workaround for an error that is raised on ecto.migrate when adding
  `PriceSpotter.Repos.MongoRepo` to the ecto_repos configuration in config.exs.

  """
  use Mix.Task

  require Logger

  @impl Mix.Task
  def run(_args) do
    Logger.info("Creating mongodb indexes...")
    {:ok, _} = Application.ensure_all_started(:price_spotter)

    Mongo.Ecto.create_indexes(PriceSpotter.Repos.MongoRepo, :products, [
      %{key: %{product_id: 1}, name: "product_id", unique: true}
    ])

    Application.stop(:price_spotter)
    Logger.info("Finished creating mongodb indexes.")
  end
end
