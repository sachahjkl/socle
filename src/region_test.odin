package socle

import "core:testing"
import "core:time"

// A zone's offset follows its summer time, and reads as a search finds it (region.md).
@(test)
a_zone_s_offset_follows_the_season :: proc(t: ^testing.T) {
	winter, _ := time.components_to_time(2026, 1, 15, 12, 0, 0)
	summer, _ := time.components_to_time(2026, 7, 15, 12, 0, 0)
	testing.expect_value(t, zone_offset("Europe/Paris", winter), 3600)
	testing.expect_value(t, zone_offset("Europe/Paris", summer), 7200)
	testing.expect_value(t, zone_offset("Asia/Kolkata", winter), 19800)
	testing.expect_value(t, zone_offset("America/New_York", winter), -18000)
	testing.expect_value(t, offset_words(0), "UTC")
	testing.expect_value(t, offset_words(32400), "UTC+9")
	testing.expect_value(t, offset_words(19800), "UTC+5:30")
	testing.expect_value(t, offset_words(-12600), "UTC-3:30")
}
