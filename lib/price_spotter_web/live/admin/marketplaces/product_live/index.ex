defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Index do
  use PriceSpotterWeb, :live_view
  use PriceSpotterWeb.Navigation, :action

  alias PriceSpotter.Accounts
  alias PriceSpotter.Marketplaces
  alias PriceSpotter.Marketplaces.Product
  alias PriceSpotterWeb.Admin.ExpandableList

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    {:ok,
     assign(socket, %{
       products: nil,
       meta: nil,
       expanded: ExpandableList.new()
     })}
  end

  @impl true
  def handle_params(params, _url, socket) do
    list_params = Map.drop(params, ["id"])

    case Marketplaces.list_products_by_user(
           list_params,
           socket.assigns.current_user
         ) do
      {:ok, {products, meta}} ->
        {:noreply,
         socket
         |> assign(%{products: products, meta: meta, list_params: list_params})
         |> assign_selection_options()
         |> assign_filter_fields()
         |> assign(filter_fields_form: to_form(meta))
         |> assign_header_action()
         |> assign(:section_title, gettext("Products"))
         |> apply_action(socket.assigns.live_action, params)
         |> maybe_include_selected_product()}

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

    # {:noreply,
    #   push_patch(socket, to: ~p"/admin/marketplaces/products?#{params}")}
  end

  @impl true
  def handle_event("reset-filter", _params, %{assigns: assigns} = socket) do
    flop =
      assigns.meta.flop
      |> Flop.reset_filters()
      |> Map.merge(%{after: nil, before: nil})

    path =
      Flop.Phoenix.build_path(~p"/admin/marketplaces/products", flop,
        backend: assigns.meta.backend
      )

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    product = Marketplaces.get_product_for_user!(id, user)

    case Marketplaces.delete_product_for_user(product, user) do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: ~p"/admin/marketplaces/products")}

      {:error, :unauthorized} ->
        {:noreply, unauthorized_delete(socket)}
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    product =
      Marketplaces.get_product_for_user!(id, socket.assigns.current_user)

    socket
    |> assign(:page_title, gettext("Edit Product"))
    |> assign(:expanded, MapSet.new([product.id]))
    |> assign(:product, product)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    product =
      Marketplaces.get_product_for_user!(id, socket.assigns.current_user)

    socket
    |> assign(:page_title, gettext("Listing Products"))
    |> assign(:expanded, MapSet.new([product.id]))
    |> assign(:product, product)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New Product"))
    |> assign(:expanded, ExpandableList.new())
    |> assign(:product, %Product{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Listing Products"))
    |> assign(:expanded, ExpandableList.new())
    |> assign(:product, nil)
  end

  defp maybe_include_selected_product(
         %{
           assigns: %{
             live_action: action,
             product: %Product{id: id} = product,
             products: products
           }
         } = socket
       )
       when action in [:show, :edit] and is_binary(id) do
    if Enum.any?(products, &(&1.id == id)) do
      socket
    else
      assign(socket, :products, [product | products])
    end
  end

  defp maybe_include_selected_product(socket), do: socket

  defp unauthorized_delete(socket) do
    put_flash(
      socket,
      :error,
      gettext("You are not allowed to delete products")
    )
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent,
         {:saved, product}},
        socket
      ) do
    {:noreply, refresh_products(socket, product)}
  end

  @impl true
  def handle_info({:product_inline_saved, _product}, socket) do
    {:noreply,
     put_flash(socket, :info, gettext("Product updated successfully"))}
  end

  defp refresh_products(socket, product) do
    list_params = Map.get(socket.assigns, :list_params, %{})

    case Marketplaces.list_products_by_user(
           list_params,
           socket.assigns.current_user
         ) do
      {:ok, {products, meta}} ->
        socket
        |> assign(:products, products)
        |> assign(:meta, meta)
        |> assign_selection_options()
        |> assign_filter_fields()
        |> assign(filter_fields_form: to_form(meta))
        |> maybe_include_selected_product()

      _error ->
        products =
          Enum.map(socket.assigns.products, fn existing ->
            if existing.id == product.id, do: product, else: existing
          end)

        assign(socket, :products, products)
    end
  end

  @spec maybe_render_category(String.t() | nil) :: String.t()
  def maybe_render_category(category) do
    case category do
      nil ->
        gettext("Unassigned")

      category ->
        String.replace(category, "-", " ")
    end
  end

  defp assign_selection_options(socket) do
    socket
    |> assign(
      :product_categories,
      Marketplaces.list_product_categories_by_user(socket.assigns.current_user)
      |> Enum.filter(fn category -> category != nil end)
    )
    |> assign(
      :product_suppliers,
      Marketplaces.list_suppliers_by_user(socket.assigns.current_user)
    )
  end

  defp assign_filter_fields(socket) do
    fields = [
      name: [
        label: gettext("Product"),
        op: :ilike,
        placeholder: gettext("Filter by product name")
      ],
      ean: [
        label: gettext("EAN"),
        op: :ilike,
        placeholder: gettext("Search by EAN"),
        type: "number",
        new_feature: true
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
        placeholder: gettext("Choose a minimum price"),
        type: "number"
      ],
      max_price: [
        label: gettext("Max Price"),
        op: :<=,
        placeholder: gettext("Choose a maximum price"),
        type: "number"
      ]
    ]

    assign(socket, :filter_fields, fields)
  end

  defp get_column_names,
    do: Enum.map_join(get_columns(), ",", &Atom.to_string(Map.get(&1, :name)))

  defp get_columns,
    do: [
      %{name: :name, label: gettext("Product")},
      %{name: :ean, label: gettext("EAN")},
      %{name: :price, label: gettext("Price")},
      %{name: :price_updated_at, label: gettext("Last Price Update")},
      %{name: :supplier_name, label: gettext("Supplier")},
      %{name: :category, label: gettext("Category")},
      %{name: :img_url, label: gettext("Image URL")},
      %{name: :supplier_url, label: gettext("Product URL")}
    ]

  defp get_max_limit, do: Product.max_limit()

  defp get_limit, do: Product.limit()

  defp can_edit_products?(user), do: Accounts.can_edit_products?(user)
  defp can_delete_products?(user), do: Accounts.can_delete_products?(user)

  defp expanded_product?(expanded, product_id),
    do: ExpandableList.expanded?(expanded, product_id)

  defp products_index_path(meta) do
    Flop.Phoenix.build_path(~p"/admin/marketplaces/products", meta.flop,
      backend: meta.backend
    )
  end

  defp product_expand_path(product, user, meta) do
    path =
      if can_edit_products?(user) do
        ~p"/admin/marketplaces/products/#{product}/edit"
      else
        ~p"/admin/marketplaces/products/#{product}"
      end

    Flop.Phoenix.build_path(path, meta.flop, backend: meta.backend)
  end

  defp toggle_expand_path(product, user, expanded, meta) do
    case expanded_product?(expanded, product.id) do
      true -> products_index_path(meta)
      false -> product_expand_path(product, user, meta)
    end
  end

  defp product_price(nil), do: "–"
  defp product_price(price), do: "$#{price}"

  defp render_header_action(assigns) do
    ~H"""
    <.navigation_back navigate={~p"/"} />
    """
  end
end
