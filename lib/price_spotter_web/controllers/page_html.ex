defmodule PriceSpotterWeb.PageHTML do
  use PriceSpotterWeb, :html
  alias Decimal, as: D

  embed_templates "page_html/*"

  @doc """
  A compact homepage summary metric card.

  `tone` drives the directional color treatment: `:neutral` for plain totals,
  `:up` (green) for increases and `:down` (red) for decreases.
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :tone, :atom, default: :neutral, values: [:neutral, :up, :down]

  def metric_card(assigns) do
    ~H"""
    <div class={["rounded-xl border px-4 py-3", metric_card_container(@tone)]}>
      <p class={["text-xs uppercase tracking-wide", metric_card_label(@tone)]}>
        <%= @label %>
      </p>
      <p class={["mt-1 text-2xl font-semibold", metric_card_value(@tone)]}>
        <%= @value %>
      </p>
    </div>
    """
  end

  @doc """
  A highlighted top-mover card (most increased / decreased product in 24h).

  Pass `direction: :up` for increases (green, `+` delta) and `direction: :down`
  for decreases (red, `-` delta). When `mover` is `nil` the `empty_text` state
  is rendered instead.
  """
  attr :title, :string, required: true
  attr :mover, :map, default: nil
  attr :direction, :atom, required: true, values: [:up, :down]
  attr :empty_text, :string, required: true

  def top_mover_card(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-200 bg-zinc-50 px-4 py-4 dark:border-zinc-700 dark:bg-zinc-900/30">
      <h2 class="text-sm font-semibold text-zinc-800 dark:text-zinc-200">
        <%= @title %>
      </h2>
      <%= if @mover do %>
        <div class="mt-3 flex items-start gap-3">
          <div class="h-16 w-16 shrink-0 overflow-hidden rounded-md border border-zinc-200 bg-zinc-200 dark:border-zinc-700 dark:bg-zinc-800">
            <img
              :if={@mover.product_image != nil}
              src={@mover.product_image}
              alt={@mover.product_name}
              class="h-full w-full object-cover"
            />
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium text-zinc-800 dark:text-zinc-200">
              <%= @mover.product_name %>
            </p>
            <div class="mt-1 flex flex-wrap gap-2">
              <.pill text={@mover.supplier_name} variant={:info} />
              <.pill
                :if={@mover.category_name}
                text={@mover.category_name}
                variant={:neutral}
              />
            </div>
            <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-300">
              <%= gettext("Current price") %>: <%= format_money(
                @mover.current_price
              ) %>
            </p>
            <p class={["text-sm font-semibold", mover_delta_color(@direction)]}>
              <%= mover_delta_sign(@direction) %><%= format_money(
                mover_absolute_delta(@mover)
              ) %> (<%= format_percentage(@mover.percentage_delta) %>)
            </p>
          </div>
        </div>
      <% else %>
        <p class="mt-3 text-sm text-zinc-500 dark:text-zinc-400">
          <%= @empty_text %>
        </p>
      <% end %>
    </div>
    """
  end

  def format_money(nil), do: "-"

  def format_money(%D{} = amount) do
    "$#{D.round(amount, 2) |> D.to_string(:normal)}"
  end

  def format_percentage(nil), do: "-"

  def format_percentage(%D{} = percentage) do
    "#{D.round(percentage, 2) |> D.to_string(:normal)}%"
  end

  defp metric_card_container(:up),
    do:
      "border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/20"

  defp metric_card_container(:down),
    do: "border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-900/20"

  defp metric_card_container(_tone),
    do: "border-zinc-200 bg-zinc-50 dark:border-zinc-700 dark:bg-zinc-900/30"

  defp metric_card_label(:up), do: "text-green-700 dark:text-green-300"
  defp metric_card_label(:down), do: "text-red-700 dark:text-red-300"
  defp metric_card_label(_tone), do: "text-zinc-500 dark:text-zinc-400"

  defp metric_card_value(:up), do: "text-green-800 dark:text-green-300"
  defp metric_card_value(:down), do: "text-red-800 dark:text-red-300"
  defp metric_card_value(_tone), do: "text-zinc-800 dark:text-zinc-200"

  defp mover_delta_color(:up), do: "text-green-700 dark:text-green-300"
  defp mover_delta_color(:down), do: "text-red-700 dark:text-red-300"

  defp mover_delta_sign(:up), do: "+"
  defp mover_delta_sign(:down), do: "-"

  # Movement deltas always arrive as Decimals from the metrics query; normalize
  # to a Decimal magnitude (the direction drives the sign) or nil so that any
  # unexpected shape renders as "-" via format_money/1 rather than crashing.
  defp mover_absolute_delta(%{absolute_delta: %D{} = delta}), do: D.abs(delta)
  defp mover_absolute_delta(_mover), do: nil
end
