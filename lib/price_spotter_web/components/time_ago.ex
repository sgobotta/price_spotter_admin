defmodule TimeAgo do
  import PriceSpotterWeb.Gettext

  def time_ago(datetime) do
    now = NaiveDateTime.utc_now()
    time_diff = NaiveDateTime.diff(now, datetime, :second)

    case time_diff do
      _ when time_diff < 30 -> "just now"
      _ when time_diff < 60 -> "less than a minute ago"
      _ when time_diff < 3600 -> format_minutes(time_diff)
      _ when time_diff < 86400 -> format_hours(time_diff)
      _ when time_diff < 2592000 -> format_days(time_diff)
      _ when time_diff < 31104000 -> format_months(time_diff)
      _ -> format_years(time_diff)
    end
  end

  defp format_minutes(seconds) do
    minutes = div(seconds, 60)
    ngettext("%{minutes} minute ago", "%{minutes} minutes ago", minutes, minutes: minutes)
  end

  defp format_hours(seconds) do
    hours = div(seconds, 3600)
    "#{hours} hour#{pluralize(hours)} ago"
  end

  defp format_days(seconds) do
    days = div(seconds, 86400)
    "#{days} day#{pluralize(days)} ago"
  end

  defp format_months(seconds) do
    months = div(seconds, 2592000)
    "#{months} month#{pluralize(months)} ago"
  end

  defp format_years(seconds) do
    years = div(seconds, 31104000)
    "#{years} year#{pluralize(years)} ago"
  end

  defp pluralize(1), do: ""
  defp pluralize(_), do: "s"
end
