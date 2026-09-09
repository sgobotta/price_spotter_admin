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
    {:ok, _} = Marketplaces.delete_product(socket.assigns.product)

    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    %Marketplaces.Product{
      name: product_name
    } = product = Marketplaces.get_product!(id)

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
                            } = product ->
        history =
          case Marketplaces.fetch_prices_history(product_id, interval) do
            {:ok, fetched_history} -> fetched_history
            :error -> []
          end

        %{
          label: chart_series_label(product, supplier_name),
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

  defp chart_series_label(%Marketplaces.Product{name: name}, supplier_name) do
    case supplier_name do
      nil -> name
      _supplier_name -> "#{name} - #{supplier_name}"
    end
  end

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

  defp render_price(price), do: "$#{price}"

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
