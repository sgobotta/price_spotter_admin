defmodule PriceSpotter.Extractor.CronHumanizer do
  @moduledoc """
  Translates the common shapes of 5-field cron expressions used by the
  extractor service's spiders into a short human-readable summary.

  Cron strings from that service are free-form (admins can type anything
  the extractor accepts), so this only recognizes a handful of common
  patterns and always falls back to the raw cron string for anything else -
  it never raises on unrecognized input.
  """

  @spec humanize(String.t()) :: String.t()
  def humanize(cron) when is_binary(cron) do
    case String.split(cron) do
      [minute, hour, "*", "*", "*"] -> humanize_daily(minute, hour, cron)
      _fields -> cron
    end
  end

  defp humanize_daily("*/" <> step, "*", cron), do: every_minutes(step, cron)
  defp humanize_daily("0", "*/" <> step, cron), do: every_hours(step, cron)
  defp humanize_daily("0", "0", _cron), do: "Daily at midnight"
  defp humanize_daily(minute, "*", cron), do: hourly_at_minute(minute, cron)

  defp humanize_daily(minute, hour, cron) do
    with {m, ""} <- Integer.parse(minute),
         {h, ""} <- Integer.parse(hour),
         true <- m in 0..59 and h in 0..23 do
      "Daily at #{pad(h)}:#{pad(m)}"
    else
      _invalid -> cron
    end
  end

  defp every_minutes(step, cron) do
    with {n, ""} <- Integer.parse(step), true <- n > 0 do
      "Every #{n} minute#{plural(n)}"
    else
      _invalid -> cron
    end
  end

  defp hourly_at_minute(minute, cron) do
    with {m, ""} <- Integer.parse(minute), true <- m in 0..59 do
      if m == 0, do: "Every hour", else: "Every hour, at minute #{m}"
    else
      _invalid -> cron
    end
  end

  defp every_hours(step, cron) do
    with {n, ""} <- Integer.parse(step), true <- n > 0 do
      "Every #{n} hour#{plural(n)}"
    else
      _invalid -> cron
    end
  end

  defp plural(1), do: ""
  defp plural(_n), do: "s"

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
