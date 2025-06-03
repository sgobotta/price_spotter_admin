defmodule Mix.Tasks.PriceSpotter.Mongo.Migrate do
  @moduledoc """
  This module is responsible of defining a task that helps developers run mongo
  migrations.

  This is a workaround for an error that is raised on ecto.migrate when adding
  `PriceSpotter.Repos.MongoRepo` to the ecto_repos configuration in config.exs.

  """
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    PriceSpotter.Mongo.Migrator.migrate()
  end
end
