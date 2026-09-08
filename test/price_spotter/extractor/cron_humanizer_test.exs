defmodule PriceSpotter.Extractor.CronHumanizerTest do
  use ExUnit.Case, async: true

  alias PriceSpotter.Extractor.CronHumanizer

  describe "humanize/1" do
    test "renders common interval schedules" do
      assert CronHumanizer.humanize("*/5 * * * *") == "Every 5 minutes"
      assert CronHumanizer.humanize("0 */2 * * *") == "Every 2 hours"
    end

    test "renders daily schedules with 24 hour format" do
      assert CronHumanizer.humanize("0 3 * * *") == "At 03:00"
      assert CronHumanizer.humanize("15 14 * * *") == "At 14:15"
    end

    test "renders weekday schedules" do
      assert CronHumanizer.humanize("0 9 * * 1") == "At 09:00, only on Monday"

      assert CronHumanizer.humanize("30 8 * * 1-5") ==
               "At 08:30, Monday through Friday"
    end

    test "falls back to raw cron for invalid expressions" do
      assert CronHumanizer.humanize("not a cron") == "not a cron"
      assert CronHumanizer.humanize("60 25 * * *") == "60 25 * * *"
    end
  end

  describe "preview/1" do
    test "returns a humanized summary for a valid cron expression" do
      assert CronHumanizer.preview("0 9 * * 1") ==
               {:ok, "At 09:00, only on Monday"}
    end

    test "returns an error tuple for an invalid expression" do
      assert CronHumanizer.preview("not a cron") == {:error, :invalid}
    end
  end
end
