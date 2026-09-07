defmodule PriceSpotter.Extractor.RunWatcher do
  @moduledoc """
  Connects to the extractor service's run-stream WebSocket
  (`GET /admin/spiders/runs/<run_id>/stream`) and forwards each decoded
  message to the parent process as `{:extractor_run_event, run_id,
  decoded_message}`.

  Started linked to its parent (typically the LiveView watching the run),
  so it dies with it. The extractor closes the connection itself once the
  run finishes - per its docs that's a normal "run's over" signal, not an
  error, so this process does not attempt to reconnect on disconnect.
  """

  use WebSockex

  require Logger

  @spec start_link(String.t(), String.t(), String.t(), pid()) ::
          {:ok, pid()} | {:error, term()}
  def start_link(run_id, stream_url, stream_token, parent_pid) do
    WebSockex.start_link(ws_url(stream_url, stream_token), __MODULE__, %{
      run_id: run_id,
      parent: parent_pid
    })
  end

  @impl WebSockex
  def handle_frame({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, decoded} ->
        send(state.parent, {:extractor_run_event, state.run_id, decoded})

      {:error, reason} ->
        Logger.error("Failed to decode extractor run frame: #{inspect(reason)}")
    end

    {:ok, state}
  end

  def handle_frame(_frame, state), do: {:ok, state}

  defp ws_url(stream_url, stream_token) do
    base_url = Application.fetch_env!(:price_spotter, :extractor)[:ws_base_url]
    base_url <> stream_url <> "?token=" <> stream_token
  end
end
