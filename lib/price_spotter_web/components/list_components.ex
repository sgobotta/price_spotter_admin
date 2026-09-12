defmodule PriceSpotterWeb.ListComponents do
  @moduledoc """
  Row-based list components used to replace raw `<table>` markup on admin
  index pages. Pairs with `Flop`/`Flop.Phoenix` for sorting and cursor
  pagination state.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PriceSpotterWeb.CoreComponents
  import PriceSpotterWeb.Gettext

  @doc """
  Renders a list of rows inside a bordered container, with an empty state
  shown when `items` is empty.

  ## Examples

      <.list_group id="suppliers" items={@suppliers}>
        <:empty_state>No suppliers found.</:empty_state>
        <:row :let={supplier}>
          <.list_row><:title><%= supplier.name %></:title></.list_row>
        </:row>
      </.list_group>
  """
  attr :id, :string, required: true
  attr :items, :list, required: true
  attr :class, :string, default: nil

  slot :empty_state
  slot :row, required: true

  def list_group(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "divide-y divide-zinc-200 overflow-x-hidden dark:divide-zinc-700",
        "rounded-lg border border-zinc-200 bg-white dark:border-zinc-700 dark:bg-zinc-900",
        @class
      ]}
    >
      <%= if @items == [] do %>
        <div class="py-10">
          <%= render_slot(@empty_state) %>
        </div>
      <% else %>
        <%= for item <- @items do %>
          <%= render_slot(@row, item) %>
        <% end %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single row inside a `<.list_group>`.
  """
  attr :id, :string, default: nil
  attr :click, :any, default: nil

  slot :leading
  slot :title, required: true
  slot :subtitle
  slot :meta
  slot :trailing
  slot :actions

  def list_row(assigns) do
    ~H"""
    <div
      id={@id}
      phx-click={@click}
      class={[
        "group flex items-center gap-3 px-4 py-3 transition-colors",
        "hover:bg-zinc-50 dark:hover:bg-zinc-800/60",
        @click && "cursor-pointer"
      ]}
    >
      <div :if={@leading != []} class="shrink-0">
        <%= render_slot(@leading) %>
      </div>

      <div class="min-w-0 flex-1">
        <div class="text-sm font-medium text-zinc-800 dark:text-zinc-200">
          <%= render_slot(@title) %>
        </div>
        <div
          :if={@subtitle != []}
          class="mt-1 text-xs text-zinc-500 dark:text-zinc-400"
        >
          <%= render_slot(@subtitle) %>
        </div>
      </div>

      <div
        :if={@meta != []}
        class="hidden shrink-0 flex-wrap items-center justify-end gap-1 sm:flex"
      >
        <%= render_slot(@meta) %>
      </div>

      <div
        :if={@trailing != []}
        class="hidden shrink-0 text-xs italic text-zinc-500 dark:text-zinc-400 sm:block"
      >
        <%= render_slot(@trailing) %>
      </div>

      <div
        :if={@actions != []}
        class="flex shrink-0 items-center gap-2 opacity-0 transition-opacity group-hover:opacity-100"
      >
        <%= render_slot(@actions) %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a row with a standardized expand/collapse panel.
  """
  attr :id, :string, required: true
  attr :expanded, :boolean, required: true
  attr :toggle_event, :string, default: "toggle_expand"
  attr :toggle_key, :any, required: true
  attr :toggle_patch, :any, default: nil
  attr :content_class, :string, default: nil

  slot :leading
  slot :title, required: true
  slot :subtitle
  slot :meta
  slot :trailing
  slot :actions
  slot :content, required: true

  def expandable_list_row(assigns) do
    assigns = assign(assigns, :header_click, header_click(assigns))

    ~H"""
    <div id={@id} class="flex min-w-0 flex-col px-4 py-3">
      <div class="flex w-full min-w-0 flex-col gap-3 sm:flex-row sm:items-center sm:justify-between sm:gap-4">
        <div
          id={"#{@id}-header"}
          phx-click={@header_click}
          phx-value-key={if @toggle_patch, do: nil, else: @toggle_key}
          aria-expanded={@expanded}
          aria-controls={"#{@id}-expand"}
          class="flex min-w-0 flex-1 cursor-pointer items-center gap-3 overflow-hidden"
        >
          <div :if={@leading != []} class="shrink-0">
            <%= render_slot(@leading) %>
          </div>

          <div class="min-w-0 flex-1 overflow-hidden">
            <div class="truncate text-sm font-medium text-zinc-800 dark:text-zinc-200">
              <%= render_slot(@title) %>
            </div>
            <div
              :if={@subtitle != []}
              class="mt-1 text-xs text-zinc-500 dark:text-zinc-400"
            >
              <%= render_slot(@subtitle) %>
            </div>
          </div>

          <div
            :if={@meta != []}
            class="hidden shrink-0 flex-wrap items-center justify-end gap-1 sm:flex"
          >
            <%= render_slot(@meta) %>
          </div>

          <div
            :if={@trailing != []}
            class="hidden shrink-0 text-xs italic text-zinc-500 dark:text-zinc-400 sm:block"
          >
            <%= render_slot(@trailing) %>
          </div>

          <span
            class="inline-flex shrink-0 text-zinc-400 dark:text-zinc-500"
            aria-hidden="true"
          >
            <CoreComponents.icon
              name={
                if @expanded,
                  do: "hero-chevron-up-solid",
                  else: "hero-chevron-down-solid"
              }
              class="h-4 w-4"
            />
          </span>
          <span class="sr-only">
            <%= if @expanded, do: gettext("Collapse"), else: gettext("Expand") %>
          </span>
        </div>

        <div
          :if={@actions != []}
          class="flex shrink-0 items-center gap-2 self-end sm:self-auto"
        >
          <%= render_slot(@actions) %>
        </div>
      </div>

      <div
        id={"#{@id}-expand"}
        role="region"
        aria-hidden={if @expanded, do: "false", else: "true"}
        class={[
          "grid transition-all duration-300 ease-in-out",
          if(@expanded,
            do: "grid-rows-[1fr] opacity-100",
            else: "grid-rows-[0fr] opacity-0"
          )
        ]}
      >
        <%= if @expanded do %>
          <div class="overflow-hidden">
            <div class={[
              "mt-3 rounded-lg border border-zinc-100 bg-zinc-50 p-3 dark:border-zinc-800 dark:bg-zinc-900/40",
              @content_class
            ]}>
              <%= render_slot(@content) %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp header_click(%{toggle_patch: patch}) when not is_nil(patch),
    do: JS.patch(patch)

  defp header_click(%{toggle_event: event}), do: event

  @doc """
  Renders a sortable header row for a `<.list_group>`, replacing a `<thead>`.
  Columns with a `:field` become sort links built from `meta`/`path`.
  """
  attr :meta, Flop.Meta, required: true
  attr :path, :any, required: true

  slot :col do
    attr :field, :atom
    attr :label, :string
    attr :class, :string
  end

  def list_header(assigns) do
    ~H"""
    <div class="hidden items-center gap-3 border-b border-zinc-200 bg-zinc-50 px-4 py-2 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-400 sm:flex">
      <%= for col <- @col do %>
        <%= if col[:field] do %>
          <.link
            patch={sort_path(@path, @meta, col[:field])}
            class={[
              col[:class],
              "flex items-center gap-1 hover:text-zinc-800 dark:hover:text-zinc-200"
            ]}
          >
            <%= col[:label] %>
            <CoreComponents.icon
              :if={sort_direction(@meta, col[:field]) == :asc}
              name="hero-chevron-up-solid"
              class="h-3 w-3"
            />
            <CoreComponents.icon
              :if={sort_direction(@meta, col[:field]) == :desc}
              name="hero-chevron-down-solid"
              class="h-3 w-3"
            />
          </.link>
        <% else %>
          <span class={col[:class]}><%= col[:label] %></span>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp sort_path(path, meta, field) do
    flop = Flop.push_order(meta.flop, field)
    Flop.Phoenix.build_path(path, flop, backend: meta.backend)
  end

  defp sort_direction(
         %Flop.Meta{flop: %Flop{order_by: order_by, order_directions: dirs}},
         field
       ) do
    case Enum.find_index(order_by || [], &(&1 == field)) do
      nil -> nil
      idx -> Enum.at(dirs || [], idx, :asc)
    end
  end

  @palette [
    {"bg-rose-100 text-rose-700 dark:bg-rose-900/50 dark:text-rose-300"},
    {"bg-amber-100 text-amber-700 dark:bg-amber-900/50 dark:text-amber-300"},
    {"bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300"},
    {"bg-sky-100 text-sky-700 dark:bg-sky-900/50 dark:text-sky-300"},
    {"bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300"}
  ]

  @doc """
  Renders a small rounded tile with the first letter of `label`, colored
  deterministically from a hash of `label`. Used in place of a missing
  avatar image on entities that have no image field.
  """
  attr :label, :string, required: true
  attr :class, :string, default: nil

  def entity_avatar(assigns) do
    assigns = assign(assigns, :palette_class, palette_for(assigns.label))

    ~H"""
    <div class={[
      "flex h-8 w-8 items-center justify-center rounded-full text-xs font-semibold",
      @palette_class,
      @class
    ]}>
      <%= initial(@label) %>
    </div>
    """
  end

  defp initial(label) when label in [nil, ""], do: "?"

  defp initial(label),
    do: label |> String.trim() |> String.first() |> String.upcase()

  defp palette_for(label) do
    {classes} = Enum.at(@palette, :erlang.phash2(label || "", length(@palette)))
    classes
  end
end
