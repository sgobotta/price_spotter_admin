defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Show do
  use PriceSpotterWeb, :live_view

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
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:product, Marketplaces.get_product!(id))}
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
           internal_id: internal_id,
           name: product_name,
           supplier_name: supplier_name
         } <- socket.assigns.product,
         {:ok, history} <-
           Marketplaces.fetch_product_history(
             supplier_name,
             internal_id,
             socket.assigns.interval
           ) do
      socket = push_event(socket, "reset-dataset", %{label: product_name})

      socket =
        Enum.reduce(build_dataset(product_name, history), socket, fn data,
                                                                     acc ->
          push_event(acc, "new-point", data)
        end)

      {:noreply, socket}
    else
      _error ->
        {:noreply,
         socket
         |> push_event("reset-dataset", %{label: socket.assigns.product.name})
         |> push_event("new-point", %{
           data_label: get_datetime_label(DateTime.utc_now()),
           label: socket.assigns.product.name,
           value: 0
         })
         |> put_flash(
           :error,
           gettext("There was an error loading the price chart")
         )}
    end
  end

  defp page_title(:show), do: gettext("Show Product")
  defp page_title(:edit), do: gettext("Edit Product")

  defp render_chart(assigns) do
    ~H"""
    <canvas id="chart-canvas" phx-update="ignore" phx-hook="LineChart" />
    """
  end

  @spec build_dataset(String.t(), [
          {NaiveDateTime.t(), Marketplaces.Product.t()}
        ]) :: [map()]
  defp build_dataset(product_name, product_history) do
    dataset_trend =
      product_history
      |> Enum.map(fn {_ts, %Marketplaces.Product{price: price}} -> price end)
      |> Enum.reverse()
      |> get_dataset_trend

    {background_color, border_color} = get_chart_colors(dataset_trend)

    Enum.map(product_history, fn {datetime, %Marketplaces.Product{price: price}} ->
      %{
        data_label: get_datetime_label(datetime),
        label: product_name,
        value: price,
        background_color: background_color,
        border_color: border_color
      }
    end)
  end

  defp get_datetime_label(%DateTime{} = datetime),
    do: DatetimeUtils.human_readable_datetime(datetime, :shift_timezone)

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
    if String.length(ean) === 13 do
      {country_code, rest} = String.split_at(ean, 2)
      {manufacturer_code, rest} = String.split_at(rest, 5)
      {product_code, rest} = String.split_at(rest, 5)
      {check_digit, ""} = String.split_at(rest, 1)

      "#{country_code} #{manufacturer_code} #{product_code} #{check_digit}"
    else
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

  # ----------------------------------------------------------------------------
  # Assignment functions
  #

  @spec assign_interval(Phoenix.LiveView.Socket.t(), Marketplaces.interval()) ::
          Phoenix.LiveView.Socket.t()
  defp assign_interval(socket, interval \\ :daily),
    do: assign(socket, :interval, interval)
end
