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
        {:noreply,
         socket
         |> assign(%{products: products, meta: meta})
         |> assign_selection_options()
         |> assign_filter_fields()
         |> assign(:total, meta.total_count)
         |> assign(filter_fields_form: to_form(meta))
         |> apply_action(socket.assigns.live_action, params)}

      _error ->
        {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
    end
  end

  @impl true
  def handle_event("update-filter", params, socket) do
    {:noreply,
     push_patch(socket,
       to:
         ~p"/admin/marketplaces/products"
         |> URI.parse()
         |> Map.put(:query, Plug.Conn.Query.encode(params))
         |> URI.to_string()
     )}

    # {:noreply, push_patch(socket, to: ~p"/admin/marketplaces/products?#{params}")}
  end

  @impl true
  def handle_event("reset-filter", _, %{assigns: assigns} = socket) do
    flop = assigns.meta.flop |> Flop.set_page(1) |> Flop.reset_filters()

    path =
      Flop.Phoenix.build_path(~p"/admin/marketplaces/products", flop,
        backend: assigns.meta.backend
      )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Marketplaces.get_product!(id)
    {:ok, _} = Marketplaces.delete_product(product)

    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
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
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent, {:saved, _product}},
        socket
      ) do
    {:noreply, socket}
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

  defp assign_selection_options(socket) do
    socket
    |> assign(:product_categories, Marketplaces.list_product_categories())
    |> assign(:product_suppliers, Marketplaces.list_product_supplier())
  end

  defp assign_filter_fields(socket) do
    fields = [
      name: [
        label: gettext("Product"),
        op: :like
      ],
      category: [
        label: gettext("Category"),
        type: "select",
        prompt: gettext("All categories"),
        options: socket.assigns.product_categories
      ],
      supplier_name: [
        label: gettext("Supplier"),
        type: "select",
        prompt: gettext("All suppliers"),
        options: socket.assigns.product_suppliers
      ],
      price_updated_since: [
        label: gettext("Last Update"),
        op: :>=,
        type: "datetime-local"
      ],
      min_price: [
        label: gettext("Min Price"),
        op: :>=,
        type: "number"
      ],
      max_price: [
        label: gettext("Max Price"),
        op: :<=,
        type: "number"
      ]
    ]
    assign(socket, :filter_fields, fields)
  end

  defp get_column_names, do: Enum.join(Enum.map(get_columns(), &Atom.to_string(Map.get(&1, :name))), ",")

  defp get_columns, do: [
    %{name: :name, label: gettext("Product")},
    %{name: :price, label: gettext("Price")},
    %{name: :price_updated_at, label: gettext("Last Price Update")},
    %{name: :supplier_name, label: gettext("Supplier")},
    %{name: :category, label: gettext("Category")},
    %{name: :img_url, label: gettext("Image URL")},
    %{name: :supplier_url, label: gettext("Product URL")}
  ]

  defp get_max_limit, do: Product.max_limit()

  defp get_limit, do: Product.limit()
end
