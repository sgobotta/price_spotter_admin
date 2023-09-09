defmodule PriceSpotterWeb.Admin.Marketplaces.ProductLive.Show do
  use PriceSpotterWeb, :live_view

  alias PriceSpotter.Marketplaces

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :update_chart, 500)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:product, Marketplaces.get_product!(id))}
  end

  @impl true
  def handle_info(
        {PriceSpotterWeb.Admin.Marketplaces.ProductLive.FormComponent, {:saved, _product}},
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
         {:ok, history} <- Marketplaces.fetch_product_history(supplier_name, internal_id) do
      socket =
        Enum.reduce(build_dataset(product_name, history), socket, fn data, acc ->
          push_event(acc, "new-point", data)
        end)

      {:noreply, socket}
    else
      _error ->
        {:noreply,
         socket
         |> push_event("new-point", %{
           data_label: get_datetime_label(NaiveDateTime.utc_now()),
           label: socket.assigns.product.name,
           value: 0
         })
         |> put_flash(:error, gettext("There was an error loading the price chart"))}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Marketplaces.delete_product(socket.assigns.product)

    {:noreply, push_navigate(socket, to: ~p"/admin/marketplaces/products")}
  end

  defp page_title(:show), do: gettext("Show Product")
  defp page_title(:edit), do: gettext("Edit Product")

  defp render_chart(assigns) do
    ~H"""
    <canvas id="chart-canvas" phx-update="ignore" phx-hook="LineChart" height="200" width="300" />
    """
  end

  @spec build_dataset(String.t(), [{NaiveDateTime.t(), Marketplaces.Product.t()}]) :: [map()]
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

  defp get_datetime_label(%NaiveDateTime{
         year: year,
         month: month,
         day: day,
         hour: hour,
         minute: minute
       }) do
    minute = if minute < 10, do: "0#{minute}", else: minute
    "#{day}/#{month}/#{year} #{hour}:#{minute}hs"
  end

  defp get_dataset_trend([]), do: :bullish
  defp get_dataset_trend([_price]), do: :bullish

  defp get_dataset_trend([last_price, price | _rest] = l) when last_price == price do
    :notrend
  end

  defp get_dataset_trend([last_price, price | _rest]) when last_price > price, do: :bullish
  defp get_dataset_trend(_price_history), do: :bearish

  defp get_chart_colors(:notrend), do: {"rgba(203, 213, 225, 1)", "rgba(100, 116, 139, 1)"}
  defp get_chart_colors(:bullish), do: {"rgba(167, 243, 208, 1)", "rgba(16, 185, 129, 1)"}
  defp get_chart_colors(:bearish), do: {"rgba(253, 164, 175, 1)", "rgba(244, 63, 94, 1)"}
end
