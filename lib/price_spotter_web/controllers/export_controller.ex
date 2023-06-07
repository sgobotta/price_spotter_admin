defmodule PriceSpotterWeb.ExportController do
  use PriceSpotterWeb, :controller

  def create(conn, %{"all_pages" => all_pages?, "columns" => columns, "max_limit" => max_limit} = params) do
    with columns <- parse_columns(columns),
         params <- sanitize_empty_params(params),
         params <- maybe_put_max_limit(all_pages?, params, max_limit),
         fields <- parse_fields(params, columns),
         {:ok, {products, _meta}} <- PriceSpotter.Marketplaces.list_products(params),
         csv_data <- csv_content(products, fields) do

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"export.csv\"")
      |> send_resp(200, csv_data)
    end
  end

  defp parse_columns(columns), do: String.split(columns, ",")

  defp sanitize_empty_params(params) do
    Enum.reduce(params, %{}, fn
      {_k, ""}, acc ->
        acc

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  defp maybe_put_max_limit("true", params, max_limit), do: Map.put(params, "limit", max_limit)
  defp maybe_put_max_limit("false", params, _max_limit), do: params

  defp parse_fields(params, columns) do
    Enum.reduce(params, [], fn {field, active}, acc ->
      if active == "true" and Enum.member?(columns, field),
        do: [String.to_existing_atom(field)|acc],
        else: acc
    end)
  end

  defp csv_content(records, fields) do
    records
    |> Enum.map(fn record ->
      record
      |> Map.from_struct()
      |> Map.take([]) # gives an empty map
      |> Map.merge(Map.take(record, fields))
      |> Map.values()
    end)
    |> CSV.encode()
    |> Enum.to_list()
    |> to_string()
  end
end
