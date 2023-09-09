defmodule TimeAgo do
  import PriceSpotterWeb.Gettext

  def time_ago(nil), do: gettext("Unknown")

  def time_ago(datetime) do
    now = NaiveDateTime.utc_now()
    time_diff = NaiveDateTime.diff(now, datetime, :second)

    case time_diff do
      _diff when time_diff < 30 -> gettext("just now")
      _diff when time_diff < 60 -> gettext("less than a minute ago")
      _diff when time_diff < 3600 -> format_minutes(time_diff)
      _diff when time_diff < 86_400 -> format_hours(time_diff)
      _diff when time_diff < 2_592_000 -> format_days(time_diff)
      _diff when time_diff < 31_104_000 -> format_months(time_diff)
      _diff -> format_years(time_diff)
    end
  end

  defp format_minutes(seconds) do
    minutes = div(seconds, 60)

    ngettext("%{minutes} minute ago", "%{minutes} minutes ago", minutes, minutes: minutes)
    |> String.downcase()
  end

  defp format_hours(seconds) do
    hours = div(seconds, 3600)

    ngettext("%{hours} hour ago", "%{hours} hours ago", hours, hours: hours)
    |> String.downcase()
  end

  defp format_days(seconds) do
    days = div(seconds, 86_400)

    ngettext("%{days} day ago", "%{days} days ago", days, days: days)
    |> String.downcase()
  end

  defp format_months(seconds) do
    months = div(seconds, 2_592_000)

    ngettext("%{months} month ago", "%{months} months ago", months, months: months)
    |> String.downcase()
  end

  defp format_years(seconds) do
    years = div(seconds, 31_104_000)

    ngettext("%{years} year ago", "%{years} years ago", years, years: years)
    |> String.downcase()
  end
end
