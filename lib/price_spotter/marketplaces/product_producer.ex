defmodule PriceSpotter.Marketplaces.ProductProducer do
  use Broadway

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {OffBroadwayRedisStream.Producer,
           [
             redis_client_opts: [
               host: System.get_env("REDIS_HOST", "localhost"),
               password: System.get_env("REDIS_PASS", "123456")
             ],
             stream: get_stream(),
             group: "processor-group",
             consumer_name: hostname(),
             make_stream: true
           ]}
      ],
      processors: [
        default: [min_demand: 0, max_demand: 10]
      ]
    )
  end

  def handle_message(_processor, message, _context) do
    Logger.debug("Loading product from message=#{inspect(message)}")
    %Redis.Stream.Entry{} = entry = Redis.Client.parse_stream_entry(message.data)

    {:ok, :loaded, _product} = load_product(entry)

    message
  end

  @max_attempts 5

  def handle_failed(messages, _) do
    for message <- messages do
      if message.metadata.attempt < @max_attempts do
        Broadway.Message.configure_ack(message, retry: true)
      else
        Logger.warn("Dropping product from message=#{inspect(message)}")
        [id, _] = message.data
        id
      end
    end
  end

  defp hostname do
    {:ok, host} = :inet.gethostname()
    to_string(host)
  end

  defp load_product(%Redis.Stream.Entry{values: values}) do
    {:ok, _product} = PriceSpotter.Marketplaces.load_product(values["product_stream_key"])
    {:ok, :loaded, %{}}
  end

  defp get_stream, do: "#{get_stage()}_stream_new-products_la-golosineria_v1"

  defp get_stage, do: PriceSpotter.Application.stage()
end
