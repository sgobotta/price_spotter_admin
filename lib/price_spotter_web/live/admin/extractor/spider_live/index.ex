defmodule PriceSpotterWeb.Admin.Extractor.SpiderLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Extractor
  alias PriceSpotter.Extractor.Spider
  alias PriceSpotterWeb.Admin.ExpandableList

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
     |> assign(
       page_title: gettext("Extractors"),
       active_run: nil,
       log_seq: 0,
       eans_drafts: %{},
       cron_drafts: %{},
       cron_previews: %{},
       cron_errors: %{},
       expanded: ExpandableList.new()
     )
     |> stream(:run_log, [])}
  end

  @impl true
  def handle_event("toggle_expand", %{"key" => key}, socket) do
    expanded = ExpandableList.toggle(socket.assigns.expanded, key)

    {:noreply, assign(socket, :expanded, expanded)}
  end

  @impl true
  def handle_event("update_eans", %{"key" => key, "eans" => eans}, socket) do
    {:noreply, update(socket, :eans_drafts, &Map.put(&1, key, eans))}
  end

  @impl true
  def handle_event("toggle_active", %{"key" => key}, socket) do
    case find_spider(socket.assigns.spiders, key) do
      nil ->
        {:noreply, socket}

      %Spider{active: active} ->
        key
        |> Extractor.update_schedule(%{active: !active})
        |> handle_toggle_result(socket)
    end
  end

  @impl true
  def handle_event("preview_cron", %{"key" => key, "cron" => cron}, socket) do
    {:noreply,
     socket
     |> update(:cron_drafts, &Map.put(&1, key, cron))
     |> put_cron_feedback(key, cron)}
  end

  @impl true
  def handle_event("save_cron", %{"key" => key, "cron" => cron}, socket) do
    if String.trim(cron) == "" do
      {:noreply,
       socket
       |> put_cron_error(
         key,
         gettext("Please enter a cron expression so we can save the schedule.")
       )}
    else
      case Extractor.preview_cron(cron) do
        {:ok, _summary} ->
          key
          |> Extractor.update_schedule(%{cron: cron})
          |> handle_cron_save_result(socket, key)

        {:error, :invalid} ->
          {:noreply,
           socket
           |> put_cron_error(
             key,
             gettext(
               "We couldn't read that schedule yet. Please check the cron format."
             )
           )}
      end
    end
  end

  @impl true
  def handle_event("run", %{"key" => key, "dry_run" => dry_run}, socket) do
    dry_run? = dry_run == "true"
    eans = parse_eans(Map.get(socket.assigns.eans_drafts, key))

    case Extractor.trigger_run(key, dry_run: dry_run?, eans: eans) do
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
                 eans: eans,
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

  defp handle_toggle_result({:ok, updated_spider}, socket) do
    {:noreply, update_spider(socket, updated_spider)}
  end

  defp handle_toggle_result({:error, %{message: message}}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  defp handle_cron_save_result({:ok, updated_spider}, socket, key) do
    {:noreply,
     socket
     |> update_spider(updated_spider)
     |> clear_cron_feedback(key)
     |> put_flash(:info, gettext("Schedule saved successfully."))}
  end

  defp handle_cron_save_result({:error, %{message: message}}, socket, key) do
    {:noreply,
     socket
     |> put_cron_error(key, message)}
  end

  defp parse_eans(nil), do: []

  defp parse_eans(raw) do
    raw
    |> String.split(~r/\r\n|\r|\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
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

  defp put_cron_feedback(socket, key, cron) do
    if String.trim(cron) == "" do
      clear_cron_feedback(socket, key)
    else
      case Extractor.preview_cron(cron) do
        {:ok, summary} ->
          socket
          |> update(:cron_previews, &Map.put(&1, key, summary))
          |> update(:cron_errors, &Map.delete(&1, key))

        {:error, :invalid} ->
          put_cron_error(
            socket,
            key,
            gettext(
              "We couldn't read that schedule yet. Please check the cron format."
            )
          )
      end
    end
  end

  defp clear_cron_feedback(socket, key) do
    socket
    |> update(:cron_drafts, &Map.delete(&1, key))
    |> update(:cron_previews, &Map.delete(&1, key))
    |> update(:cron_errors, &Map.delete(&1, key))
  end

  defp put_cron_error(socket, key, message) do
    socket
    |> update(:cron_previews, &Map.delete(&1, key))
    |> update(:cron_errors, &Map.put(&1, key, message))
    |> put_flash(:error, message)
  end

  defp cron_summary(%{name: name, cron: cron}, previews) do
    Map.get(previews, name, Extractor.humanize_cron(cron))
  end

  defp run_log_line(%{status: "finished"}), do: gettext("Finished")
  defp run_log_line(%{item: nil, stats: stats}), do: format_stats(stats)

  defp run_log_line(%{item: item, stats: stats}),
    do: "#{item} — #{format_stats(stats)}"

  defp format_stats(stats) when stats in [nil, %{}], do: ""

  defp format_stats(stats),
    do: stats |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)
end
