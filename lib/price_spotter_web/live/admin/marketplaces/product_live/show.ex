defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Show do
  use PriceSpotterWeb, :live_view
  use PriceSpotterWeb.Navigation, :action

  alias PriceSpotter.Accounts
  alias PriceSpotter.Marketplaces
  alias PriceSpotterWeb.Utils.DatetimeUtils

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)

    if connected?(socket) do
      Process.send_after(self(), :update_chart, 500)
    end

    {:ok,
     socket
     |> assign(:copy_clicked, false)
     |> assign(:flush_main_top, true)
     |> assign(:ean_listings, empty_ean_listings())
     |> assign_interval()}
  end

  @impl true
  def handle_event("copy_ean", _params, socket) do
    {:noreply, assign(socket, :copy_clicked, true)}
  end

  @impl true
  def handle_event("interval_change", %{"interval" => interval}, socket) do
    interval = String.to_existing_atom(interval)
    Process.send_after(self(), :update_chart, 50)

    {:noreply,
     socket
     |> assign_interval(interval)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Marketplaces.delete_product_for_user(
           socket.assigns.product,
           socket.assigns.current_user
         ) do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}

      {:error, :unauthorized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("You are not allowed to delete products")
         )}
    end
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    %Marketplaces.Product{
      name: product_name
    } =
      product =
      Marketplaces.get_product_for_user!(id, socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:page_title, product_name)
     |> assign_header_action()
     |> assign(
       :section_title,
       page_title(socket.assigns.live_action)
     )
     |> assign(:product, product)
     |> assign_ean_listings(product)}
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent,
         {:saved, _product}},
        socket
      ) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_chart, socket) do
    case socket.assigns do
      %{
        product: %Marketplaces.Product{} = product,
        ean_listings: %{visible: visible}
      } ->
        chart_data =
          build_chart_data(
            [product | visible],
            socket.assigns.interval,
            product.id
          )

        {:noreply, push_event(socket, "set-chart-data", chart_data)}

      _error ->
        {:noreply,
         push_event(socket, "set-chart-data", %{
           labels: [],
           datasets: [],
           timezone: DatetimeUtils.timezone()
         })}
    end
  end

  defp page_title(:show), do: gettext("Show Product")
  defp page_title(:edit), do: gettext("Edit Product")

  defp render_chart(assigns) do
    ~H"""
    <canvas
      id="chart-canvas"
      class="block h-full w-full max-w-full"
      phx-update="ignore"
      phx-hook="LineChart"
    />
    """
  end

  @spec build_chart_data(
          [Marketplaces.Product.t()],
          Marketplaces.interval(),
          String.t()
        ) :: map()
  defp build_chart_data(products, interval, current_product_id) do
    series =
      Enum.map(products, fn %Marketplaces.Product{
                              id: product_id,
                              supplier_name: supplier_name
                            } ->
        history =
          case Marketplaces.fetch_prices_history(product_id, interval) do
            {:ok, fetched_history} -> fetched_history
            :error -> []
          end

        %{
          label: chart_series_label(supplier_name),
          history: history,
          current?: product_id == current_product_id
        }
      end)

    %{
      labels: [],
      timezone: DatetimeUtils.timezone(),
      datasets:
        series
        |> Enum.with_index()
        |> Enum.map(fn {item, index} -> build_dataset(item, index) end)
    }
  end

  @spec build_dataset(map(), integer()) :: map()
  defp build_dataset(
         %{history: history, label: label, current?: current?},
         index
       ) do
    dataset_trend =
      history
      |> Enum.map(fn {_ts, %Marketplaces.ProductPriceDocument{price: price}} ->
        price
      end)
      |> Enum.reverse()
      |> get_dataset_trend()

    {background_color, border_color} =
      chart_series_colors(current?, index, dataset_trend)

    %{
      label: label,
      data:
        history
        |> Enum.map(&chart_point/1)
        |> Enum.reject(fn point -> point.y == nil end),
      background_color: background_color,
      border_color: border_color
    }
  end

  defp chart_point({datetime, %Marketplaces.ProductPriceDocument{price: price}}) do
    timestamp = get_timestamp(datetime)

    %{
      x: timestamp,
      y: to_chart_price(price),
      formatted_x: format_chart_label(timestamp)
    }
  end

  defp to_chart_price(%Decimal{} = price), do: Decimal.to_float(price)

  defp to_chart_price(price) when is_number(price), do: price / 1

  defp to_chart_price(price) when is_binary(price) do
    case Float.parse(price) do
      {number, _rest} -> number
      :error -> nil
    end
  end

  defp format_chart_label(timestamp),
    do: timestamp |> DateTime.from_unix!(:millisecond) |> get_datetime_label()

  defp get_datetime_label(%DateTime{} = datetime),
    do: DatetimeUtils.human_readable_datetime(datetime, :shift_timezone)

  defp get_timestamp(%DateTime{} = datetime),
    do: DateTime.to_unix(datetime, :millisecond)

  defp chart_series_label(nil), do: gettext("Unknown")

  defp chart_series_label(supplier_name),
    do: String.replace(supplier_name, "-", " ")

  defp get_dataset_trend([]), do: :bullish
  defp get_dataset_trend([_price]), do: :bullish

  defp get_dataset_trend([last_price, price | _rest]) do
    case Decimal.compare(last_price, price) do
      :eq -> :notrend
      :gt -> :bullish
      :lt -> :bearish
    end
  end

  defp get_chart_colors(:notrend),
    do: {"rgba(203, 213, 225, 1)", "rgba(100, 116, 139, 1)"}

  defp get_chart_colors(:bullish),
    do: {"rgba(167, 243, 208, 1)", "rgba(16, 185, 129, 1)"}

  defp get_chart_colors(:bearish),
    do: {"rgba(253, 164, 175, 1)", "rgba(244, 63, 94, 1)"}

  @comparison_palette [
    {"rgba(186, 230, 253, 1)", "rgba(14, 165, 233, 1)"},
    {"rgba(253, 230, 138, 1)", "rgba(202, 138, 4, 1)"},
    {"rgba(221, 214, 254, 1)", "rgba(124, 58, 237, 1)"},
    {"rgba(254, 215, 170, 1)", "rgba(234, 88, 12, 1)"},
    {"rgba(165, 180, 252, 1)", "rgba(79, 70, 229, 1)"}
  ]

  defp chart_series_colors(true, _index, trend), do: get_chart_colors(trend)

  defp chart_series_colors(false, index, _trend) do
    Enum.at(
      @comparison_palette,
      rem(index, length(@comparison_palette))
    )
  end

  # ----------------------------------------------------------------------------
  # Render functions
  #

  attr :id, :string, required: true
  attr :label, :string, required: true
  slot :inner_block, required: true

  defp detail_row(assigns) do
    ~H"""
    <div id={@id} class="flex items-center justify-between gap-4 p-3 sm:p-4">
      <dt class="shrink-0 text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
        <%= @label %>
      </dt>
      <dd class="min-w-0 text-right text-sm text-zinc-700 dark:text-zinc-200">
        <%= render_slot(@inner_block) %>
      </dd>
    </div>
    """
  end

  defp render_price(price), do: "$#{price}"

  @spec price_delta(term(), term()) ::
          %{cmp: :lt | :gt | :eq, label: String.t()} | nil
  defp price_delta(listing_price, current_price) do
    with %Decimal{} = listing <- to_decimal(listing_price),
         %Decimal{} = current <- to_decimal(current_price),
         true <- not Decimal.eq?(current, Decimal.new(0)) do
      amount = Decimal.sub(listing, current)

      percent =
        amount
        |> Decimal.div(current)
        |> Decimal.mult(100)
        |> Decimal.round(1)

      %{
        cmp: Decimal.compare(amount, Decimal.new(0)),
        label: "#{signed_money(amount)} (#{signed_percent(percent)})"
      }
    else
      _other -> nil
    end
  end

  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp to_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _other -> nil
    end
  end

  defp to_decimal(_value), do: nil

  defp signed_money(%Decimal{} = amount),
    do: "#{signed_prefix(amount)}$#{Decimal.abs(amount)}"

  defp signed_percent(%Decimal{} = percent),
    do: "#{signed_prefix(percent)}#{Decimal.abs(percent)}%"

  defp signed_prefix(%Decimal{} = value) do
    case Decimal.compare(value, Decimal.new(0)) do
      :lt -> "−"
      _other -> "+"
    end
  end

  @hidden_meta_keys MapSet.new(["origen", "crawl_index"])

  @spec product_meta_rows(map() | nil) :: [map()]
  defp product_meta_rows(meta) when not is_map(meta) or meta == %{}, do: []

  defp product_meta_rows(meta) do
    meta
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Enum.reject(fn {key, value} ->
      MapSet.member?(@hidden_meta_keys, key) or blank_meta_value?(value)
    end)
    |> Enum.map(fn {key, value} ->
      %{
        id: "product-meta-#{key}",
        label: meta_label(key),
        value: format_meta_value(key, value)
      }
    end)
    |> Enum.sort_by(& &1.label)
  end

  defp blank_meta_value?(nil), do: true
  defp blank_meta_value?(""), do: true
  defp blank_meta_value?(_value), do: false

  defp meta_label("stock"), do: gettext("Stock")
  defp meta_label("list_price"), do: gettext("List price")
  defp meta_label("price_per_kg"), do: gettext("Price per kg")
  defp meta_label("price_without_taxes"), do: gettext("Price without taxes")

  defp meta_label(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_meta_value("stock", true), do: gettext("In stock")
  defp format_meta_value("stock", false), do: gettext("Out of stock")
  defp format_meta_value("stock", "in_stock"), do: gettext("In stock")
  defp format_meta_value("stock", "out_of_stock"), do: gettext("Out of stock")

  defp format_meta_value(key, value)
       when key in ["list_price", "price_per_kg", "price_without_taxes"] do
    render_price(value)
  end

  defp format_meta_value(_key, value) when is_boolean(value) do
    if value, do: gettext("Yes"), else: gettext("No")
  end

  defp format_meta_value(_key, value)
       when is_binary(value) or is_number(value) or is_atom(value) do
    to_string(value)
  end

  defp format_meta_value(_key, value), do: inspect(value)

  @spec format_ean_string(nil | String.t()) :: String.t()
  defp format_ean_string(nil), do: gettext("Unassigned")

  defp format_ean_string(ean) do
    case String.length(ean) do
      8 ->
        {first, rest} = String.split_at(ean, 4)
        {second, ""} = String.split_at(rest, 4)

        "#{first} #{second}"

      13 ->
        {country_code, rest} = String.split_at(ean, 2)
        {manufacturer_code, rest} = String.split_at(rest, 5)
        {product_code, rest} = String.split_at(rest, 5)
        {check_digit, ""} = String.split_at(rest, 1)

        "#{country_code} #{manufacturer_code} #{product_code} #{check_digit}"

      14 ->
        {units_in_package, rest} = String.split_at(ean, 1)
        {country_code, rest} = String.split_at(rest, 2)
        {manufacturer_code, rest} = String.split_at(rest, 5)
        {product_code, rest} = String.split_at(rest, 5)
        {check_digit, ""} = String.split_at(rest, 1)

        "#{units_in_package} #{country_code} #{manufacturer_code} #{product_code} #{check_digit}"

      _other ->
        ean
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

  defp render_header_action(assigns) do
    ~H"""
    <.navigation_back navigate={~p"/admin/marketplaces/products/"} />
    """
  end

  # ----------------------------------------------------------------------------
  # Assignment functions
  #

  @spec assign_interval(Phoenix.LiveView.Socket.t(), Marketplaces.interval()) ::
          Phoenix.LiveView.Socket.t()
  defp assign_interval(socket, interval \\ :daily),
    do: assign(socket, :interval, interval)

  @spec assign_ean_listings(
          Phoenix.LiveView.Socket.t(),
          Marketplaces.Product.t()
        ) :: Phoenix.LiveView.Socket.t()
  defp assign_ean_listings(socket, product) do
    assign(
      socket,
      :ean_listings,
      Marketplaces.list_other_ean_listings(
        product,
        socket.assigns.current_user
      )
    )
  end

  defp empty_ean_listings, do: %{visible: [], hidden_supplier_count: 0}

  defp has_ean_listings?(%{visible: [], hidden_supplier_count: 0}), do: false
  defp has_ean_listings?(_ean_listings), do: true
end
