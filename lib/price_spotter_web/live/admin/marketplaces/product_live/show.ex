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
     |> assign(:product, product)}
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
    with %Marketplaces.Product{
           ean: ean
         } = product <- socket.assigns.product do
      products =
        case ean do
          nil -> [product]
          _ean -> Marketplaces.list_products_by_ean(ean)
        end

      chart_data = build_chart_data(products, socket.assigns.interval)

      socket = push_event(socket, "set-chart-data", chart_data)

      {:noreply, socket}
    else
      _error ->
        {:noreply,
         push_event(socket, "set-chart-data", %{
           labels: [],
           datasets: []
         })}
    end
  end

  defp page_title(:show), do: gettext("Show Product")
  defp page_title(:edit), do: gettext("Edit Product")

  defp render_chart(assigns) do
    ~H"""
    <canvas id="chart-canvas" phx-update="ignore" phx-hook="LineChart" />
    """
  end

  @spec build_chart_data([Marketplaces.Product.t()], Marketplaces.interval()) ::
          map()
  defp build_chart_data(products, interval) do
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
          history: history
        }
      end)

    labels =
      series
      |> Enum.flat_map(fn %{history: history} ->
        Enum.map(history, fn {datetime, _price_doc} ->
          get_timestamp(datetime)
        end)
      end)
      |> Enum.uniq()
      |> Enum.sort()

    %{
      labels: Enum.map(labels, &format_chart_label/1),
      datasets: Enum.map(series, &build_dataset(&1, labels))
    }
  end

  @spec build_dataset(map(), [integer()]) :: map()
  defp build_dataset(%{history: history, label: label}, labels) do
    price_by_timestamp =
      Map.new(history, fn {datetime,
                           %Marketplaces.ProductPriceDocument{price: price}} ->
        {get_timestamp(datetime), price}
      end)

    dataset_trend =
      history
      |> Enum.map(fn {_ts, %Marketplaces.ProductPriceDocument{price: price}} ->
        price
      end)
      |> Enum.reverse()
      |> get_dataset_trend()

    {background_color, border_color} = get_chart_colors(dataset_trend)

    %{
      label: label,
      data: Enum.map(labels, &Map.get(price_by_timestamp, &1)),
      background_color: background_color,
      border_color: border_color
    }
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

  defp get_dataset_trend([last_price, price | _rest])
       when last_price == price do
    :notrend
  end

  defp get_dataset_trend([last_price, price | _rest]) when last_price > price,
    do: :bullish

  defp get_dataset_trend(_price_history), do: :bearish

  defp get_chart_colors(:notrend),
    do: {"rgba(203, 213, 225, 1)", "rgba(100, 116, 139, 1)"}

  defp get_chart_colors(:bullish),
    do: {"rgba(167, 243, 208, 1)", "rgba(16, 185, 129, 1)"}

  defp get_chart_colors(:bearish),
    do: {"rgba(253, 164, 175, 1)", "rgba(244, 63, 94, 1)"}

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
end
