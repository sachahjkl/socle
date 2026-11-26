package socle

// The Region page: the time zone, the language and the keyboard of the machine, in the person's layer
// (src/md/features/region.md).

import "core:fmt"
import "core:slice"
import "core:strings"
import "core:time"
import lucide "gt:lucide"
import "gt:ui"

ZONE_PATH     :: "time.timeZone"
LOCALE_PATH   :: "i18n.defaultLocale"
KEYBOARD_PATH :: "services.xserver.xkb.layout"

// The zones a search shows.
@(private = "file") ZONE_HITS :: 8

region_page :: proc(app: ^App, em: f32) {
	page_head("Region", "The time, the language and the keyboard of this machine.", em)

	section("Time zone", em)
	zone := text_at(app, ZONE_PATH)
	if picked, ok := zone_picker(app, zone, changed(app, ZONE_PATH), em); ok { set_text(app, ZONE_PATH, picked) }

	section("Language and keyboard", em)
	if ui.list_card("###language_card") {
		if ui.card_row("###language") {
			setting_words("language", "Language", "The words of the system and of its apps, the dates and the numbers.", changed(app, LOCALE_PATH), em)
			locale := text_at(app, LOCALE_PATH)
			names := make([dynamic]string, context.temp_allocator)
			chosen := -1
			for l, i in LANGUAGES {
				append(&names, l.title)
				if l.locale == locale { chosen = i }
			}
			// (a locale set by hand stays, under its own name, until another is picked)
			if chosen < 0 { append(&names, locale); chosen = len(names) - 1 }
			if ui.dropdown("###language_pick", names[:], &chosen) && chosen < len(LANGUAGES) {
				set_text(app, LOCALE_PATH, LANGUAGES[chosen].locale)
			}
		}
		if ui.card_row("###keyboard") {
			setting_words("keyboard", "Keyboard", "On the desktop and on the console, where the disk's passphrase is typed.", changed(app, KEYBOARD_PATH), em)
			layout := text_at(app, KEYBOARD_PATH)
			names := make([dynamic]string, context.temp_allocator)
			chosen := -1
			for k, i in KEYBOARDS {
				append(&names, k[0])
				if k[1] == layout { chosen = i }
			}
			if chosen < 0 { append(&names, layout); chosen = len(names) - 1 }
			if ui.dropdown("###keyboard_pick", names[:], &chosen) && chosen < len(KEYBOARDS) {
				set_text(app, KEYBOARD_PATH, KEYBOARDS[chosen][1])
			}
		}
	}
}

// The time zone `current` (its offset, its time now) and a search of the others: the Region page's and the installer's.
// `picked`: the zone clicked this frame.
zone_picker :: proc(app: ^App, current: string, changed_mark: bool, em: f32) -> (picked: string, ok: bool) {
	index_need(app, &app.zones, .Zones)
	zone := current != "" ? current : "UTC"
	if ui.list_card("###zone_card") {
		if ui.card_row("###zone_now") {
			setting_words("zone", zone, zone_line(app, zone), changed_mark, em)
		}
		if ui.card_row("###zone_find") {
			ui.next({width = ui.fill(), height = ui.px(ui.control_height()), radius = em * 0.45})
			if ui.input_frame("###zone_search") {
				ui.next({width = ui.px(em * 2), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center})
				ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.SEARCH + "###zone_search_icon")
				ui.next({width = ui.fill(), height = ui.pct(1)})
				if ui.tags("bare") { ui.line_edit("###zone_field", &app.zone_search, {placeholder = "A city, a country or an offset: paris, new york, utc+9"}) }
			}
		}
	}
	return zone_hits(app, zone, em)
}

// "UTC+1 · 14:05 now": the zone's offset and its time, which the window keeps to the minute.
@(private = "file")
zone_line :: proc(app: ^App, zone: string) -> string {
	e, ok := zone_entry(app, zone != "" ? zone : "UTC")
	if !ok { return "" }
	now := time.now()
	t := time.time_add(now, time.Duration(e.offset) * time.Second)
	h, m, s := time.clock_from_time(t)
	// (the next minute's frame: the time shown turns with the clock)
	ui.wake_within(&app.main.state, (60 - s) * 1000)
	return fmt.tprintf("%s · %02d:%02d now", e.name, h, m)
}

// A zone of the index by its name: the entries are in the order of their names.
@(private = "file")
zone_entry :: proc(app: ^App, name: string) -> (Entry, bool) {
	if app.zones.state != .Ready { return {}, false }
	i, found := slice.binary_search_by(app.zones.entries[:], name, proc(e: Entry, n: string) -> slice.Ordering {
		return e.key < n ? .Less : e.key > n ? .Greater : .Equal
	})
	if !found { return {}, false }
	return app.zones.entries[i], true
}

// The zones that the search finds; the one clicked.
@(private = "file")
zone_hits :: proc(app: ^App, current: string, em: f32) -> (picked: string, ok: bool) {
	query := strings.to_lower(strings.trim_space(ui.line_edit_string(&app.zone_search)), context.temp_allocator)
	// (an empty query too: its answer empties the hits, so a new query never shows the hits of one before it)
	index_search(app, &app.zones, query)
	if query == "" { return "", false }
	ui.spacer(ui.px(em * 0.6))
	switch app.zones.state {
	case .Absent, .Building:
		ui.button("###zones_busy", "Reading the time zones", o = {face = .Ghost, busy = true})
	case .Failed:
		note_well("zones", lucide.ALERT_TRIANGLE, .Red, "The time zones cannot be read", app.zones.why, em)
	case .Ready:
		// (while the newest query is searched, the last answer stays: an empty list at each key made the page blink)
		if len(app.zones.hits) == 0 {
			if index_answered(&app.zones, query) { weak("No time zone says that.", "zones_none") }
			return
		}
		if ui.list_card("###zone_hits") {
			for e, i in app.zones.hits {
				if i >= ZONE_HITS { break }
				on := e.key == current
				if ui.button(fmt.tprintf("zone_hit%d", i), fmt.tprintf("%s  ·  %s", e.key, e.name), o = {face = .Row, selected = on, width = ui.fill(), left = true}).clicked && !on {
					picked, ok = e.key, true
					ui.line_edit_set(&app.zone_search, "")
				}
			}
		}
	}
	return
}
