defmodule PriceSpotter.Repo do
  use Ecto.Repo,
    otp_app: :price_spotter,
    adapter: Ecto.Adapters.Postgres
end
