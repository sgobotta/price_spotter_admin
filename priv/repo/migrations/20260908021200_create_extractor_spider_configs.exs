defmodule PriceSpotter.Repo.Migrations.CreateExtractorSpiderConfigs do
  use Ecto.Migration

  def change do
    create table(:extractor_spider_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :spider_name, :string, null: false
      add :input_config, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:extractor_spider_configs, [:spider_name])
  end
end
