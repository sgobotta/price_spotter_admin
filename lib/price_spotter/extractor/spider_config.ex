defmodule PriceSpotter.Extractor.SpiderConfig do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extractor_spider_configs" do
    field :spider_name, :string
    field :input_config, :map, default: %{}

    timestamps()
  end

  def changeset(spider_config, attrs) do
    spider_config
    |> cast(attrs, [:spider_name, :input_config])
    |> validate_required([:spider_name, :input_config])
    |> unique_constraint(:spider_name)
  end
end
