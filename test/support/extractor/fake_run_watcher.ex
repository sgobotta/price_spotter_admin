defmodule PriceSpotter.Extractor.FakeRunWatcher do
  @moduledoc """
  Test double for `PriceSpotter.Extractor.RunWatcher`. Starts a plain
  linked process instead of opening a real WebSocket connection, so tests
  that trigger a run don't depend on network access to the extractor
  service.
  """

  @spec start_link(String.t(), String.t(), String.t(), pid()) ::
          {:ok, pid()}
  def start_link(_run_id, _stream_url, _stream_token, _parent_pid) do
    {:ok, spawn_link(fn -> :ok end)}
  end
end
