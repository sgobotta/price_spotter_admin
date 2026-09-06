defmodule PriceSpotterWeb.SidebarComponent do
  @moduledoc false
  use PriceSpotterWeb, :html

  attr :current_user, :any, default: nil
  attr :current_path, :string, default: nil

  def sidebar(assigns) do
    ~H"""
    <nav
      :if={@current_user}
      class="
        hidden sm:flex sm:flex-col
        w-56 shrink-0 h-screen sticky top-0
        border-r border-dotted border-zinc-300 dark:border-zinc-700
        bg-zinc-50 dark:bg-zinc-900
        py-4 px-2 gap-1
      "
    >
      <.sidebar_link
        navigate={~p"/"}
        icon="hero-home"
        label={gettext("Home")}
        active={@current_path == "/"}
      />
      <.sidebar_link
        navigate={~p"/admin/marketplaces/products"}
        icon="hero-shopping-bag-solid"
        label={gettext("Products")}
        active={active?(@current_path, "/admin/marketplaces/products")}
      />
      <.sidebar_link
        :if={@current_user.role == :admin}
        navigate={~p"/admin/marketplaces/suppliers"}
        icon="hero-building-storefront-solid"
        label={gettext("Suppliers")}
        active={active?(@current_path, "/admin/marketplaces/suppliers")}
      />
      <.sidebar_link
        :if={@current_user.role == :admin}
        navigate={~p"/admin/accounts/users"}
        icon="hero-user-solid"
        label={gettext("Users")}
        active={active?(@current_path, "/admin/accounts/users")}
      />
      <.sidebar_link
        navigate={~p"/users/settings"}
        icon="hero-cog-6-tooth-solid"
        label={gettext("Settings")}
        active={active?(@current_path, "/users/settings")}
      />
    </nav>
    """
  end

  attr :navigate, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-semibold transition-colors duration-200",
        @active && "bg-zinc-200 dark:bg-zinc-700 text-brand",
        !@active &&
          "text-zinc-700 dark:text-zinc-300 hover:bg-zinc-100 hover:dark:bg-zinc-800"
      ]}
    >
      <.icon name={@icon} class="h-5 w-5 shrink-0" />
      <span><%= @label %></span>
    </.link>
    """
  end

  defp active?(nil, _prefix), do: false

  defp active?(current_path, prefix),
    do: String.starts_with?(current_path, prefix)
end
