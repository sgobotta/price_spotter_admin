defmodule PriceSpotterWeb.CurrentPathHook do
  @moduledoc """
  Tracks the current request path in socket assigns via an attached
  handle_params hook, so the shared layout's sidebar can highlight the
  active section without every LiveView wiring it manually.
  """
  import Phoenix.LiveView, only: [attach_hook: 4]
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:save_path, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :save_current_path, :handle_params, fn
       _params, uri, socket ->
         {:cont, assign(socket, :current_path, URI.parse(uri).path)}
     end)}
  end
end
