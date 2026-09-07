defmodule PriceSpotter.Extractor.CronHumanizerTest do
  use ExUnit.Case, async: true

  alias PriceSpotter.Extractor.CronHumanizer

  describe "humanize/1" do
    test "every N minutes" do
      assert CronHumanizer.humanize("*/5 * * * *") == "Every 5 minutes"
      assert CronHumanizer.humanize("*/1 * * * *") == "Every 1 minute"
    end

    test "every N hours" do
      assert CronHumanizer.humanize("0 */2 * * *") == "Every 2 hours"
      assert CronHumanizer.humanize("0 */1 * * *") == "Every 1 hour"
    end

    test "daily at midnight" do
      assert CronHumanizer.humanize("0 0 * * *") == "Daily at midnight"
    end

    test "hourly at a fixed minute" do
      assert CronHumanizer.humanize("0 * * * *") == "Every hour"
      assert CronHumanizer.humanize("30 * * * *") == "Every hour, at minute 30"
    end

    test "daily at a fixed time" do
      assert CronHumanizer.humanize("30 14 * * *") == "Daily at 14:30"
      assert CronHumanizer.humanize("5 9 * * *") == "Daily at 09:05"
    end

    test "falls back to the raw string for anything else" do
      assert CronHumanizer.humanize("*/5 * * * 1-5") == "*/5 * * * 1-5"
      assert CronHumanizer.humanize("not a cron") == "not a cron"
      assert CronHumanizer.humanize("60 25 * * *") == "60 25 * * *"
    end
  end
end
