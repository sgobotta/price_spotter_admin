defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Index do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Product

  @impl true
  def mount(_params, _session, socket) do
    # {:ok, stream(socket, :products, Marketplaces.list_products() |> Enum.take(10))}
    {:ok, assign(socket, %{products: nil, meta: nil})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case Marketplaces.list_products(params) do
      {:ok, {products, meta}} ->
        # IO.inspect(meta, label: "Pagination Meta")
        {:noreply,
          socket
          |> assign(%{products: products, meta: meta})
          |> assign(:total, meta.total_count)
          |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit Product"))
    |> assign(:product, Marketplaces.get_product!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Product"))
    |> assign(:product, %Product{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Listing Products"))
    |> assign(:product, nil)
  end

  @impl true
  def handle_info({PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent, {:saved, _product}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Marketplaces.get_product!(id)
    {:ok, _} = Marketplaces.delete_product(product)

    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
  end

  def render_next_icon(assigns) do
    ~H"""
    <.icon name="hero-arrow-right-solid" class="h-7 w-7" />
    """
  end

  def render_previous_icon(assigns) do
    ~H"""
    <.icon name="hero-arrow-left-solid" class="h-7 w-7" />
    """
  end
end
