defmodule PriceSpotter.Extractor.LlmClient.Anthropic do
  @moduledoc """
  Default `PriceSpotter.Extractor.LlmClient` backed by Anthropic's Messages
  API (`POST /v1/messages`).

  Elixir has no official Anthropic SDK, so this calls the REST endpoint
  directly through the app's Finch pool. The prompt states the weight/unit
  match as a hard constraint; the exploration flow still re-checks it with
  `PriceSpotter.Extractor.PackageSize`, so a model slip cannot leak a
  mismatched EAN into a candidate set.
  """
  @behaviour PriceSpotter.Extractor.LlmClient

  require Logger

  @default_base_url "https://api.anthropic.com"
  @default_model "claude-opus-5"
  @anthropic_version "2023-06-01"
  @max_tokens 1024

  @impl true
  def propose_matches(target, references, _opts) do
    config = config()

    with {:ok, api_key} <- fetch_api_key(config),
         body <- request_body(config, target, references),
         {:ok, decoded} <- post(config, api_key, body),
         {:ok, text} <- extract_text(decoded) do
      parse_proposals(text, references)
    end
  end

  defp request_body(config, target, references) do
    Jason.encode!(%{
      model: config[:model] || @default_model,
      max_tokens: @max_tokens,
      system: system_prompt(),
      messages: [%{role: "user", content: user_prompt(target, references)}]
    })
  end

  defp post(config, api_key, body) do
    url = (config[:base_url] || @default_base_url) <> "/v1/messages"

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @anthropic_version},
      {"content-type", "application/json"}
    ]

    :post
    |> Finch.build(url, headers, body)
    |> Finch.request(finch_name(config), receive_timeout: 30_000)
    |> handle_response()
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}})
       when status in 200..299 do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:error, :invalid_llm_response}
    end
  end

  defp handle_response({:ok, %Finch.Response{status: status, body: body}}) do
    Logger.error("LLM API error: status=#{status} body=#{inspect(body)}")
    {:error, %{status: status}}
  end

  defp handle_response({:error, reason}) do
    Logger.error("LLM API request failed: #{inspect(reason)}")
    {:error, :llm_unreachable}
  end

  defp extract_text(%{"content" => blocks}) when is_list(blocks) do
    text =
      blocks
      |> Enum.filter(&(&1["type"] == "text"))
      |> Enum.map_join("\n", & &1["text"])

    if text == "", do: {:error, :empty_llm_response}, else: {:ok, text}
  end

  defp extract_text(_other), do: {:error, :invalid_llm_response}

  # The model is asked for a bare JSON array; accept either that or an array
  # embedded in surrounding prose.
  defp parse_proposals(text, references) do
    with :error <- decode_json_array(text),
         :error <- decode_embedded_array(text) do
      Logger.error("Could not parse LLM proposals from: #{inspect(text)}")
      {:error, :invalid_llm_response}
    else
      {:ok, entries} -> {:ok, normalize_entries(entries, references)}
    end
  end

  defp decode_json_array(text) do
    case Jason.decode(String.trim(text)) do
      {:ok, list} when is_list(list) -> {:ok, list}
      _other -> :error
    end
  end

  # Try a greedy match first (first `[` to last `]`, so a `]` inside a string
  # value doesn't cut the array short); fall back to non-greedy so a trailing
  # bracketed aside after the array can't defeat extraction either.
  defp decode_embedded_array(text) do
    with :error <- try_array(~r/\[.*\]/s, text) do
      try_array(~r/\[.*?\]/s, text)
    end
  end

  defp try_array(regex, text) do
    case Regex.run(regex, text) do
      [json] ->
        case Jason.decode(json) do
          {:ok, list} when is_list(list) -> {:ok, list}
          _other -> :error
        end

      _no_match ->
        :error
    end
  end

  defp normalize_entries(entries, references) do
    valid_eans =
      references
      |> Enum.map(& &1.ean)
      |> MapSet.new()

    entries
    |> Enum.map(&normalize_entry/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&MapSet.member?(valid_eans, &1.ean_candidate))
    |> Enum.uniq_by(& &1.ean_candidate)
  end

  defp normalize_entry(%{"ean_candidate" => ean} = entry)
       when is_binary(ean) do
    %{
      ean_candidate: ean,
      confidence: entry["confidence"],
      reason: entry["reason"]
    }
  end

  defp normalize_entry(_other), do: nil

  defp system_prompt do
    """
    You match grocery products to their EAN barcode. You are given a TARGET \
    product that has no EAN and a numbered list of REFERENCE products that \
    already have an EAN. Return the references that are the SAME product as \
    the target.

    HARD CONSTRAINT - package size and unit must match exactly. A 200 g item \
    is NOT the same product as a 400 g item; 1 L is NOT 500 ml; a 6-pack is \
    NOT a single unit. If a reference differs from the target in weight, \
    volume, or count - even slightly - do NOT return it. When the size is \
    ambiguous, leave it out rather than guess.

    Respond with ONLY a JSON array (no prose, no code fences). Each element: \
    {"ean_candidate": "<the reference EAN>", "confidence": <0.0-1.0>, \
    "reason": "<short explanation>"}. Return an empty array [] if none match.
    """
  end

  defp user_prompt(target, references) do
    refs =
      references
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {ref, i} ->
        supplier = ref[:supplier] || "unknown"

        "#{i}. ean=#{ref.ean} | name=#{ref.name} | supplier=#{supplier}"
      end)

    """
    TARGET product (no EAN):
    name=#{target.name} | category=#{target[:category] || "unknown"}

    REFERENCE products:
    #{refs}
    """
  end

  defp fetch_api_key(config) do
    case config[:api_key] do
      key when is_binary(key) and key != "" -> {:ok, key}
      _missing -> {:error, :missing_llm_api_key}
    end
  end

  defp finch_name(config), do: config[:finch] || PriceSpotter.Finch

  defp config, do: Application.get_env(:price_spotter, :llm, [])
end
