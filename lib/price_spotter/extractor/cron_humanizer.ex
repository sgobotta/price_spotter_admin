defmodule PriceSpotter.Extractor.CronHumanizer do
  @moduledoc """
  Translates cron expressions into a human-readable summary.

  This delegates to `cronstrue_ex` for broad cron support and falls back to
  the original cron string when parsing fails.
  """

  @spec humanize(String.t()) :: String.t()
  def humanize(cron) when is_binary(cron) do
    CronstrueEx.to_string(cron, use_24_hour_time_format: true)
  rescue
    CronstrueEx.ParseError -> cron
    MatchError -> cron
  end

  @spec preview(String.t()) :: {:ok, String.t()} | {:error, :invalid}
  def preview(cron) when is_binary(cron) do
    {:ok, CronstrueEx.to_string(cron, use_24_hour_time_format: true)}
  rescue
    CronstrueEx.ParseError -> {:error, :invalid}
    MatchError -> {:error, :invalid}
  end
end
