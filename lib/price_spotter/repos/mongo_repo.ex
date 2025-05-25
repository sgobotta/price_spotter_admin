defmodule PriceSpotter.Repos.MongoRepo do
  use Ecto.Repo,
    otp_app: :price_spotter,
    adapter: Mongo.Ecto,
    on_conflict: :nothing

  def pool do
    Ecto.Adapter.lookup_meta(__MODULE__).pid
  end
end
