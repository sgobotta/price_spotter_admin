defmodule PriceSpotterWeb.ExportController do
  use PriceSpotterWeb, :controller

  def create(conn, params) do
    fields = [
      :category,
      :img_url,
      :internal_id,
      :name,
      :price,
      :price_updated_at,
      :supplier_name,
      :supplier_url
    ]

    {:ok, {products, _meta}} = PriceSpotter.Marketplaces.list_products(params)
    csv_data = csv_content(products, fields)

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"export.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, csv_data)
  end

  defp csv_content(records, fields) do
    records
    |> Enum.map(fn record ->
      record
      |> Map.from_struct()
      |> Map.take([]) # gives an empty map
      |> Map.merge( Map.take(record, fields) )
      |> Map.values()
    end)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
