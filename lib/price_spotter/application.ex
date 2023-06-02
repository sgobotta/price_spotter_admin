defmodule PriceSpotter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PriceSpotterWeb.Telemetry,
      # Start the Ecto repository
      PriceSpotter.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: PriceSpotter.PubSub},
      # Start Finch
      {Finch, name: PriceSpotter.Finch},
      # Start the Endpoint (http/https)
      PriceSpotterWeb.Endpoint,
      # Start a worker by calling: PriceSpotter.Worker.start_link(arg)
      # {PriceSpotter.Worker, arg}
      {PriceSpotter.Marketplaces.ProductProducer, []},
      {Redix, host: redis_host(), name: :redix, password: redis_pass()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PriceSpotter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PriceSpotterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  @spec env :: :dev | :test | :prod
  def env, do: Application.fetch_env!(:price_spotter, :environment)

  @spec stage :: :local | :dev
  def stage, do: Application.fetch_env!(:price_spotter, :stage)

  def redis_host, do: Application.fetch_env!(:price_spotter, :redis_host)

  def redis_pass, do: Application.fetch_env!(:price_spotter, :redis_pass)
end
