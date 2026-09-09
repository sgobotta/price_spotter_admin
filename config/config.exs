# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :price_spotter,
  ecto_repos: [PriceSpotter.Repo],
  generators: [binary_id: true]

# LLM used by the EAN match-candidate exploration flow. The API key is
# supplied at runtime (see config/runtime.exs); tests swap the client.
config :price_spotter, :llm,
  client: PriceSpotter.Extractor.LlmClient.Anthropic,
  model: "claude-opus-5"

# Maps a product's `supplier_name` (as emitted by the extractor spiders and
# stored on the product) to the extractor spider key used for the optional
# EAN price fetch in the exploration flow. Only spiders that accept an EAN
# override belong here, and the mapping is re-validated at run time against
# the extractor's live `supports_ean_override` list (the extractor is the
# source of truth). A supplier absent from this map is skipped rather than
# routed to the wrong spider. Note the supplier name and spider key are not
# always the same string (e.g. supplier "maxiconsumo" -> "maxiconsumo-by-ean-v2").
config :price_spotter, :extractor,
  ean_override_spider_by_supplier: %{
    "coto-by-ean" => "coto-by-ean",
    "maxiconsumo" => "maxiconsumo-by-ean-v2"
  }

config :flop, repo: PriceSpotter.Repo

config :flop_phoenix,
  pagination: [opts: {PriceSpotterWeb.CoreComponents, :pagination_opts}],
  table: [opts: {PriceSpotterWeb.CoreComponents, :table_opts}],
  cursor_pagination: [
    opts: {PriceSpotterWeb.CoreComponents, :cursor_pagination_opts}
  ]

# Configures the endpoint
config :price_spotter, PriceSpotterWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: PriceSpotterWeb.ErrorHTML, json: PriceSpotterWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PriceSpotter.PubSub,
  live_view: [signing_salt: "Pxm+wQWG"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :price_spotter, PriceSpotter.Mailer, adapter: Swoosh.Adapters.Local

config :gettext, :default_locale, "es_AR"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
