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
          assign(socket,
            spiders: spiders,
            eans_drafts: eans_drafts_from_spiders(spiders),
            load_error: nil
          )

        {:error, %{message: message}} ->
          assign(socket, spiders: [], eans_drafts: %{}, load_error: message)
      end

    {:ok,
     socket
     |> assign(
       page_title: gettext("Extractors"),
       active_run: nil,
       log_seq: 0,
       cron_drafts: %{},
       cron_previews: %{},
       cron_errors: %{},
       eans_errors: %{},
       ean_save_confirm: nil,
       cron_save_confirm: nil,
       toggle_confirm: nil,
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
    {:noreply,
     socket
     |> update(:eans_drafts, &Map.put(&1, key, eans))
     |> update(:eans_errors, &Map.delete(&1, key))}
  end

  @impl true
  def handle_event("prompt_save_eans", %{"key" => key} = params, socket) do
    eans =
      Map.get(params, "eans") || Map.get(socket.assigns.eans_drafts, key, "")

    parsed = Extractor.parse_eans(eans)

    {:noreply,
     socket
     |> update(:eans_drafts, &Map.put(&1, key, eans))
     |> update(:eans_errors, &Map.delete(&1, key))
     |> assign(:ean_save_confirm, %{
       key: key,
       eans: eans,
       count: length(parsed)
     })}
  end

  @impl true
  def handle_event("cancel_save_eans", _params, socket) do
    {:noreply, assign(socket, :ean_save_confirm, nil)}
  end

  @impl true
  def handle_event("confirm_save_eans", _params, socket) do
    case socket.assigns.ean_save_confirm do
      nil ->
        {:noreply, socket}

      %{key: key, eans: eans} ->
        persist_eans(assign(socket, :ean_save_confirm, nil), key, eans)
    end
  end

  @impl true
  def handle_event("prompt_toggle_active", %{"key" => key}, socket) do
    case find_spider(socket.assigns.spiders, key) do
      nil ->
        {:noreply, socket}

      %Spider{name: name, active: active} ->
        {:noreply,
         assign(socket, :toggle_confirm, %{
           key: key,
           name: name,
           activate?: !active
         })}
    end
  end

  @impl true
  def handle_event("cancel_toggle_active", _params, socket) do
    {:noreply, assign(socket, :toggle_confirm, nil)}
  end

  @impl true
  def handle_event("confirm_toggle_active", _params, socket) do
    case socket.assigns.toggle_confirm do
      nil ->
        {:noreply, socket}

      %{key: key, activate?: activate?} ->
        key
        |> Extractor.update_schedule(%{active: activate?})
        |> handle_toggle_result(assign(socket, :toggle_confirm, nil))
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
  def handle_event("prompt_save_cron", %{"key" => key, "cron" => cron}, socket) do
    socket = update(socket, :cron_drafts, &Map.put(&1, key, cron))

    if String.trim(cron) == "" do
      {:noreply,
       socket
       |> put_cron_error(
         key,
         gettext("Please enter a cron expression so we can save the schedule.")
       )}
    else
      case Extractor.preview_cron(cron) do
        {:ok, summary} ->
          {:noreply,
           socket
           |> update(:cron_previews, &Map.put(&1, key, summary))
           |> update(:cron_errors, &Map.delete(&1, key))
           |> assign(:cron_save_confirm, %{
             key: key,
             cron: cron,
             summary: summary
           })}

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
  def handle_event("cancel_save_cron", _params, socket) do
    {:noreply, assign(socket, :cron_save_confirm, nil)}
  end

  @impl true
  def handle_event("confirm_save_cron", _params, socket) do
    case socket.assigns.cron_save_confirm do
      nil ->
        {:noreply, socket}

      %{key: key, cron: cron} ->
        key
        |> Extractor.update_schedule(%{cron: cron})
        |> handle_cron_save_result(
          assign(socket, :cron_save_confirm, nil),
          key
        )
    end
  end

  @impl true
  def handle_event("run", %{"key" => key, "dry_run" => dry_run}, socket) do
    dry_run? = dry_run == "true"
    eans = Extractor.parse_eans(Map.get(socket.assigns.eans_drafts, key))

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
  def handle_event("stop_run", _params, %{assigns: %{active_run: nil}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_run", _params, socket) do
    %{run_id: run_id} = socket.assigns.active_run

    case Extractor.stop_run(run_id) do
      {:ok, _resp} ->
        {:noreply,
         socket
         |> assign(
           :active_run,
           Map.put(socket.assigns.active_run, :status, :stopping)
         )
         |> put_flash(
           :info,
           gettext(
             "Stop requested. Waiting for the extractor to finish the run."
           )
         )}

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
          | status: run_status(status),
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

  defp persist_eans(socket, key, eans) do
    case find_spider(socket.assigns.spiders, key) do
      nil ->
        {:noreply, socket}

      spider ->
        case Extractor.save_input_config(spider, eans) do
          {:ok, %{eans: normalized_eans}} ->
            {:noreply,
             socket
             |> update(
               :eans_drafts,
               &Map.put(&1, key, Enum.join(normalized_eans, "\n"))
             )
             |> update(:eans_errors, &Map.delete(&1, key))
             |> put_flash(:info, gettext("EAN configuration saved"))}

          {:error, %{reason: :not_supported, message: message}} ->
            {:noreply, put_flash(socket, :error, message)}

          {:error, %{details: details}} ->
            {:noreply,
             socket
             |> update(:eans_drafts, &Map.put(&1, key, eans))
             |> update(:eans_errors, &Map.put(&1, key, details))}
        end
    end
  end

  defp toggle_tooltip(%{active: true}), do: gettext("Click to deactivate")

  defp toggle_tooltip(%{active: false}), do: gettext("Click to activate")

  defp toggle_button_class(%{active: true}) do
    "!rounded-full text-xs focus:!shadow-none active:!shadow-none " <>
      "!bg-emerald-100 !text-emerald-800 hover:!bg-emerald-200 " <>
      "focus:!bg-emerald-200 dark:!bg-emerald-900/40 dark:!text-emerald-300 " <>
      "dark:hover:!bg-emerald-900/70 dark:focus:!bg-emerald-900/70"
  end

  defp toggle_button_class(%{active: false}) do
    "!rounded-full text-xs focus:!shadow-none active:!shadow-none " <>
      "bg-zinc-100 text-zinc-700 hover:!bg-zinc-200 focus:!bg-zinc-200 " <>
      "dark:bg-zinc-800 dark:text-zinc-200 dark:hover:!bg-zinc-700 " <>
      "dark:focus:!bg-zinc-700"
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

  defp ean_format_error_message(%{ean: ean, reason: :non_numeric}) do
    gettext("%{ean} — must contain only digits", ean: ean)
  end

  defp ean_format_error_message(%{ean: ean, reason: :invalid_length}) do
    gettext("%{ean} — must be 8, 13, or 14 digits long", ean: ean)
  end

  defp find_spider(spiders, key), do: Enum.find(spiders, &(&1.name == key))

  defp eans_drafts_from_spiders(spiders) do
    Map.new(spiders, fn spider ->
      eans = get_in(spider.input_config || %{}, ["eans"]) || []
      {spider.name, Enum.join(eans, "\n")}
    end)
  end

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
      clear_cron_feedback(socket, key, keep_draft: true)
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

  defp clear_cron_feedback(socket, key, opts \\ []) do
    keep_draft = Keyword.get(opts, :keep_draft, false)

    socket =
      if keep_draft do
        socket
      else
        update(socket, :cron_drafts, &Map.delete(&1, key))
      end

    socket
    |> update(:cron_previews, &Map.delete(&1, key))
    |> update(:cron_errors, &Map.delete(&1, key))
  end

  defp put_cron_error(socket, key, message) do
    socket
    |> update(:cron_previews, &Map.delete(&1, key))
    |> update(:cron_errors, &Map.put(&1, key, message))
    |> put_flash(:error, message)
  end

  defp saved_cron_summary(%{cron: cron}), do: Extractor.humanize_cron(cron)

  defp cron_summary(%{name: name, cron: cron}, previews) do
    Map.get(previews, name, Extractor.humanize_cron(cron))
  end

  defp run_log_line(%{status: status})
       when status in ["finished", "stopped", "cancelled", "canceled"],
       do: gettext("Finished")

  defp run_log_line(%{item: nil, stats: stats}), do: format_stats(stats)

  defp run_log_line(%{item: item, stats: stats}),
    do: "#{item} — #{format_stats(stats)}"

  defp format_stats(stats) when stats in [nil, %{}], do: ""

  defp format_stats(stats),
    do: stats |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{v}" end)

  defp run_status(status)
       when status in ["finished", "stopped", "cancelled", "canceled"],
       do: :finished

  defp run_status("stopping"), do: :stopping

  defp run_status(_status), do: :running
end
