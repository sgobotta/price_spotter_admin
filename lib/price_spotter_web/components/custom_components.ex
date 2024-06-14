defmodule PriceSpotterWeb.CustomComponents do
  @moduledoc false

  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias PriceSpotterWeb.CoreComponents

  import PriceSpotterWeb.Gettext

  attr :has_code, :boolean, required: true
  attr :ean, :string, required: true

  def no_results_found(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <CoreComponents.icon
        id="products-not-found"
        name="hero-magnifying-glass"
        class="text-black dark:text-white h-5 w-5 mx-2"
      />
      <span><%= gettext("No products found.") %></span>
    </div>
    """
  end

  def render_ean(assigns) do
    ~H"""
    <span class={"
        text-sm font-medium md:block text-center self-center bg-zinc-100
        rounded-md px-2 shadow-inner-lg border-2 border-zinc-200
        #{if @has_code, do: "text-blue-500", else: "text-yellow-500"}
      "}>
      <%= @ean %>
    </span>
    """
  end

  @doc """
  Renders a button to toggle the application theme
  """
  attr :theme, :string, required: true

  def toggle_theme_button(assigns) do
    ~H"""
    <div
      class="flex items-center gap-4 font-semibold leading-6 text-zinc-900"
      phx-hook="Theme"
      id="theme-hook"
    >
      <a
        class="hover:text-zinc-700 cursor-pointer h-5 w-5 leading-3"
        href="#"
        phx-key=";"
        phx-window-keydown={JS.dispatch("toggle-theme")}
        phx-click={JS.dispatch("toggle-theme")}
        tabindex="0"
      >
        <%= if @theme === "dark" do %>
          <CoreComponents.icon
            id="toggle-theme-icon"
            name="hero-sun-solid"
            class="text-black dark:text-white h-5 w-5 hover:text-yellow-500 hover:dark:text-yellow-500 transition-colors duration-500"
          />
        <% else %>
          <CoreComponents.icon
            id="toggle-theme-icon"
            name="hero-moon-solid"
            class="text-black dark:text-white h-5 w-5 hover:text-yellow-500 hover:dark:text-yellow-500 transition-colors duration-500"
          />
        <% end %>
      </a>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :name, :string, required: true
  attr :navigate_to, :string, required: true

  @doc """
  Renders a shortcut button that navigates to a site section.
  """
  def home_shortcut(assigns) do
    ~H"""
    <a
      href={@navigate_to}
      class="group relative rounded-2xl px-6 py-4 text-sm font-semibold leading-6 text-zinc-900 sm:py-6 text-center"
    >
      <span class="
        absolute inset-0 rounded-2xl
        bg-zinc-100 dark:bg-zinc-800
        border-[1px] dark:border-[1px] border-dashed
        border-zinc-400 dark:border-zinc-600
        transition duration-500
        group-hover:bg-zinc-200 dark:group-hover:bg-zinc-700
        group-hover:border-none
        sm:group-hover:scale-[1.02]
      ">
      </span>
      <span class="relative flex items-center gap-4 sm:flex-col">
        <CoreComponents.icon
          name={@icon}
          class="h-7 w-7 group-hover:text-brand text-zinc-600 dark:text-zinc-400 transition-all duration-300"
        />
        <span class="group-hover:text-brand text-zinc-500 dark:text-zinc-500 transition-all duration-300">
          <%= @name %>
        </span>
      </span>
    </a>
    """
  end
end
