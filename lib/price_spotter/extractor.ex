defmodule PriceSpotter.Extractor do
  @moduledoc """
  Context for managing the extractor service's spiders from the admin UI:
  listing them, editing their schedule, and triggering one-off runs with
  live progress.
  """

  alias PriceSpotter.Extractor.Client
  alias PriceSpotter.Extractor.CronHumanizer
  alias PriceSpotter.Extractor.RunWatcher

  defdelegate list_spiders, to: Client
  defdelegate update_schedule(key, attrs), to: Client
  defdelegate trigger_run(key, opts \\ []), to: Client

  @doc """
  Human-readable summary of a cron expression, falling back to the raw
  string when it doesn't match a recognized pattern.
  """
  @spec humanize_cron(String.t()) :: String.t()
  defdelegate humanize_cron(cron), to: CronHumanizer, as: :humanize

  @doc """
  Starts (linked to the caller) a process that streams a run's live
  progress into the caller as `{:extractor_run_event, run_id, message}`.
  """
  @spec watch_run(String.t(), String.t(), String.t(), pid()) ::
          {:ok, pid()} | {:error, term()}
  def watch_run(run_id, stream_url, stream_token, parent_pid \\ self()) do
    watcher().start_link(run_id, stream_url, stream_token, parent_pid)
  end

  defp watcher,
    do:
      Application.fetch_env!(:price_spotter, :extractor)[:watcher] || RunWatcher
end
