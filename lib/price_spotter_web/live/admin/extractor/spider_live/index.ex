defmodule PriceSpotterWeb.Admin.Extractor.SpiderLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Spider

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    socket =
      case Extractor.list_spiders() do
        {:ok, spiders} ->
          assign(socket, spiders: spiders, load_error: nil)

        {:error, %{message: message}} ->
          assign(socket, spiders: [], load_error: message)
      end

    {:ok,
     socket
     |> assign(page_title: gettext("Extractors"), active_run: nil, log_seq: 0)
     |> stream(:run_log, [])}
  end

  @impl true
  def handle_event("toggle_active", %{"key" => key}, socket) do
    case find_spider(socket.assigns.spiders, key) do
      nil ->
        {:noreply, socket}

      %Spider{active: active} ->
        key
        |> Extractor.update_schedule(%{active: !active})
        |> handle_schedule_result(socket)
    end
  end

  @impl true
  def handle_event("save_cron", %{"key" => key, "cron" => cron}, socket) do
    key
    |> Extractor.update_schedule(%{cron: cron})
    |> handle_schedule_result(socket)
  end

  @impl true
  def handle_event("run", %{"key" => key, "dry_run" => dry_run}, socket) do
    dry_run? = dry_run == "true"

    case Extractor.trigger_run(key, dry_run: dry_run?) do
      {:ok,
       %{run_id: run_id, stream_token: stream_token, stream_url: stream_url}} ->
        case Extractor.watch_run(run_id, stream_url, stream_token, self()) do
          {:ok, _pid} ->
            spider = find_spider(socket.assigns.spiders, key)

            {:noreply,
             socket
             |> assign(
               active_run: %{
                 spider_key: key,
                 spider_name: spider && spider.name,
                 run_id: run_id,
                 dry_run: dry_run?,
                 status: :running,
                 stats: nil
               },
               log_seq: 0
             )
             |> stream(:run_log, [], reset: true)}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               gettext("Could not connect to the run stream: %{reason}",
                 reason: inspect(reason)
               )
             )}
        end

      {:error, %{message: message}} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_info({:extractor_run_event, run_id, msg}, socket) do
    case socket.assigns.active_run do
      %{run_id: ^run_id} = active_run ->
        status = msg["status"]

        updated_run = %{
          active_run
          | status: if(status == "finished", do: :finished, else: :running),
            stats: msg["stats"]
        }

        log_entry = %{
          id: socket.assigns.log_seq,
          item: msg["item"],
          status: status,
          stats: msg["stats"]
        }

        {:noreply,
         socket
         |> assign(active_run: updated_run, log_seq: socket.assigns.log_seq + 1)
         |> stream_insert(:run_log, log_entry)}

      _other ->
        {:noreply, socket}
    end
  end

  defp handle_schedule_result({:ok, updated_spider}, socket) do
    {:noreply, update_spider(socket, updated_spider)}
  end

  defp handle_schedule_result({:error, %{message: message}}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  defp find_spider(spiders, key), do: Enum.find(spiders, &(&1.name == key))

  defp update_spider(socket, %Spider{name: name} = updated) do
    spiders =
      Enum.map(socket.assigns.spiders, fn
        %Spider{name: ^name} -> updated
        other -> other
      end)

    assign(socket, :spiders, spiders)
  end

  defp run_log_line(%{status: "finished"}), do: gettext("Finished")
  defp run_log_line(%{item: nil, stats: stats}), do: format_stats(stats)

  defp run_log_line(%{item: item, stats: stats}),
    do: "#{item} — #{format_stats(stats)}"

  defp format_stats(stats) when stats in [nil, %{}], do: ""

  defp format_stats(stats),
    do: stats |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
end
