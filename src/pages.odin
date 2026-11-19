package socle

// The pages. Each one reads the draft and writes it through draft_set, which makes the list of changes again: a page
// never compares the draft with the applied version in a frame, it reads `changed_*` from the list's makers.

import "core:fmt"
import "core:math"
import "core:strings"
import lucide "gt:lucide"
import "gt:ui"

// A page's head: its title, and a line that says what the page is.
@(private = "file")
page_head :: proc(title, line: string, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###head") {
		ui.next({width = ui.text_size(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label(fmt.tprintf("%s###head_title", title))
		if line != "" {
			ui.spacer(ui.px(em * 0.9))
			if ui.tags("weak") {
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###head_line", line))
			}
		}
	}
}

// A section's title: small, weak, in capitals, with room above it.
@(private = "file")
section :: proc(title: string, em: f32) {
	ui.spacer(ui.px(em * 1.5))
	if ui.tags("weak") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 0.82), text_pad = 0})
		ui.label(fmt.tprintf("%s###section_%s", strings.to_upper(title, context.temp_allocator), title))
	}
	ui.spacer(ui.px(em * 0.6))
}

// A line of words in the weak colour, wrapped at the room it has.
@(private = "file")
weak :: proc(text, id: string) {
	if ui.tags("weak") {
		ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
		ui.label(fmt.tprintf("%s###%s", text, id))
	}
}

// The mark of a value that the draft changes: a dot of the accent, nothing else (window.md).
@(private = "file")
changed_dot :: proc(id: string, on: bool, em: f32) {
	if !on { return }
	ui.spacer(ui.px(em * 0.5))
	// (a height of its own: a share of a row as tall as what is in it would be a height that measures itself)
	ui.next({width = ui.px(em * 0.5), height = ui.px(math.round(em * 1.3)), axis = .Y, cross = .Center})
	if ui.column(.Center, id = fmt.tprintf("###%s_slot", id)) { ui.dot(fmt.tprintf("###%s", id), em * 0.45, .Primary) }
}

// A setting's words in its card row: its title (and the changed mark), what it does; the caller's control follows at
// the right. (card_row's scope is the caller's: a helper that opened it would close it at its own return)
@(private = "file")
setting_words :: proc(id, title, about: string, changed: bool, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
	if ui.column(id = fmt.tprintf("###%s_words", id)) {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = fmt.tprintf("###%s_title_row", id)) {
			ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
			ui.label(fmt.tprintf("%s###%s_title", title, id))
			changed_dot(fmt.tprintf("%s_dot", id), changed, em)
		}
		weak(about, fmt.tprintf("%s_about", id))
	}
	ui.spacer(ui.px(em))
}

overview_page :: proc(app: ^App, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###overview_head") {
		ui.next({width = ui.text_size(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label(HOST_NAME + "###host")
		ui.spacer(ui.px(em * 0.9))
		ui.pill("template", TEMPLATE_NAME, lucide.LAYOUT_GRID, ui.color("accent"))
		ui.spacer(ui.px(em * 0.9))
		if ui.tags("weak") {
			ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
			ui.label(app.apply.at_boot ? fmt.tprintf("Version %d starts at the next start###applied", app.version) : fmt.tprintf("Version %d, applied today at 09:12###applied", app.version))
		}
	}
	ui.spacer(ui.px(em * 1.2))
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
	if ui.row(id = "###status") {
		status_card("running", len(app.changes) == 0 ? "Running your settings" : fmt.tprintf("%d changes wait", len(app.changes)),
			len(app.changes) == 0 ? "What the pages show is what runs." : "Review them in the bar under the page.",
			len(app.changes) == 0 ? lucide.CHECK_CIRCLE : lucide.CIRCLE_DOT, len(app.changes) == 0 ? .Green : .Accent, "", em)
		ui.spacer(ui.px(em * 0.75))
		if status_card("updates", "2 updates", "Software catalogue of 18 November, Family desktop 1.4.", lucide.REFRESH_CW, .Yellow, "Review", em) { app.page = .Updates }
		ui.spacer(ui.px(em * 0.75))
		status_card("space", "18.4 GB in old versions", "The last ten versions stay to go back to.", lucide.HARD_DRIVE, .Blue, "Free space", em)
	}
	section("Your system", em)
	tiles := [?]struct { page: Page, text: string }{
		{.Desktop, fmt.tprintf("%s, %s", DESKTOPS[app.draft.desktop], app.draft.dark ? "dark" : "light")},
		{.Apps, fmt.tprintf("%d for everyone", installed_count(app))},
		{.People, "Sacha, Lou, Noé"},
		{.Network, "Wi-Fi, firewall on"},
		{.Gaming, "Steam, controllers"},
		{.Printing, "Brother HL-L2350"},
		{.Sharing, "Files with the home server"},
		{.Power, "Updates on Sundays"},
	}
	for line in 0 ..< 2 {
		if line > 0 { ui.spacer(ui.px(em * 0.75)) }
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###tiles%d", line)) {
			for t, i in tiles[line * 4:][:4] {
				if i > 0 { ui.spacer(ui.px(em * 0.75)) }
				ui.next({width = ui.fill(), height = ui.children_sum()})
				if ui.card(PAGE_TITLES[t.page], PAGE_ICONS[t.page], fmt.tprintf("###tile_%v", t.page)) {
					weak(t.text, fmt.tprintf("tile_text_%v", t.page))
				}
			}
		}
	}
	section("Recent changes", em)
	if ui.list_card("###recent") {
		for v, i in app.history[:min(3, len(app.history))] {
			if ui.card_row(fmt.tprintf("###recent%d", i)) {
				if ui.tags("weak") {
					ui.next({width = ui.px(em * 8), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###recent_date%d", v.date, i))
				}
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###recent_title%d", v.title, i))
				if ui.tags("weak") {
					ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("Version %d###recent_version%d", v.number, i))
				}
			}
		}
	}
}

@(private = "file")
status_card :: proc(id, title, line, icon: string, hue: ui.Hue, act: string, em: f32) -> (clicked: bool) {
	ui.next({width = ui.fill(), height = ui.children_sum()})
	if ui.card("", id = fmt.tprintf("###status_%s", id)) {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###status_%s_row", id)) {
			ui.next({width = ui.px(em * 2), height = ui.px(em * 1.5), font = ui.lucide_icons(), font_size = em * 1.2, fg = ui.hue(hue), text_pad = 0})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, fmt.tprintf("%s###status_%s_icon", icon, id))
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
			if ui.column(id = fmt.tprintf("###status_%s_words", id)) {
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###status_%s_title", title, id))
				ui.spacer(ui.px(em * 0.2))
				weak(line, fmt.tprintf("status_%s_line", id))
				if act != "" {
					ui.spacer(ui.px(em * 0.6))
					clicked = ui.button(fmt.tprintf("status_%s_act", id), act, o = {size = .Small}).clicked
				}
			}
		}
	}
	return
}

@(private = "file")
installed_count :: proc(app: ^App) -> (n: int) {
	for on in app.draft.installed { if on { n += 1 } }
	return
}

apps_page :: proc(app: ^App, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###apps_head") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label("Apps###apps_title")
		audiences := [4]string{"For everyone", PEOPLE[0], PEOPLE[1], PEOPLE[2]}
		ui.segmented("###audience", audiences[:], &app.audience)
	}
	ui.spacer(ui.px(em * 1.1))
	ui.next({width = ui.px(em * 24), height = ui.px(ui.control_height()), radius = em * 0.45})
	if ui.input_frame("###apps_search") {
		ui.next({width = ui.px(em * 2), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center, fg = ui.color("text") * {1, 1, 1, 0.6}})
		ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.SEARCH + "###apps_search_icon")
		ui.next({width = ui.fill(), height = ui.pct(1)})
		if ui.tags("bare") { ui.line_edit("###apps_field", &app.search, {placeholder = "Search 121 860 packages"}) }
	}
	ui.spacer(ui.px(em * 0.9))
	query := strings.to_lower(ui.line_edit_string(&app.search), context.temp_allocator)
	if ui.list_card("###apps_list") {
		for p, i in CATALOGUE {
			// (fifteen packages: the real catalogue is searched on its worker, apps.md)
			if query != "" && !strings.contains(strings.to_lower(p.name, context.temp_allocator), query) &&
			   !strings.contains(strings.to_lower(p.about, context.temp_allocator), query) &&
			   !strings.contains(strings.to_lower(CATEGORY_TITLES[p.category], context.temp_allocator), query) { continue }
			app_row(app, i, em)
		}
	}
}

@(private = "file")
app_row :: proc(app: ^App, i: int, em: f32) {
	p := CATALOGUE[i]
	on, was := app.draft.installed[i], app.applied.installed[i]
	if ui.card_row(fmt.tprintf("###app%d", i)) {
		ui.next({width = ui.px(em * 2.2), height = ui.px(em * 2.2), radius = em * 0.5, bg = colour(p.colour), fg = {1, 1, 1, 1}, text_align = .Center, font_size = math.round(em * 1.05), text_pad = 0})
		ui.build_box({.Draw_Background, .Draw_Text, .No_Text_Trunc}, fmt.tprintf("%s###app_tile%d", p.letter, i))
		ui.spacer(ui.px(em * 0.9))
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
		if ui.column(id = fmt.tprintf("###app_words%d", i)) {
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
			if ui.row(id = fmt.tprintf("###app_title_row%d", i)) {
				ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###app_name%d", p.name, i))
				changed_dot(fmt.tprintf("app_dot%d", i), on != was, em)
				if p.unfree {
					ui.spacer(ui.px(em * 0.6))
					ui.pill(fmt.tprintf("app_unfree%d", i), "Not free", "", ui.hue(.Yellow))
				}
			}
			about := p.about
			if p.template && !on { about = "From the template Family desktop, removed by you" }
			weak(about, fmt.tprintf("app_about%d", i))
		}
		if ui.tags("weak") {
			ui.next({width = ui.px(em * 5), height = ui.text_size(), text_pad = 0, text_align = .Right})
			ui.label(fmt.tprintf("%s###app_version%d", p.version, i))
		}
		ui.spacer(ui.px(em * 0.9))
		ui.next({width = ui.px(em * 7.5)})
		label, icon := "Add", lucide.PLUS
		switch {
		case on && p.template && was: label, icon = "Remove", lucide.TRASH_2
		case on:                      label, icon = "Added", lucide.CHECK
		case p.template:              label, icon = "Put back", lucide.ROTATE_CCW
		}
		if ui.button(fmt.tprintf("app_act%d", i), label, icon, {size = .Small, face = label == "Put back" ? .Ghost : nil}).clicked {
			s := app.draft
			s.installed[i] = !on
			draft_set(app, s)
		}
	}
}

desktop_page :: proc(app: ^App, em: f32) {
	page_head("Desktop", "What people see after they log in.", em)
	d, a := app.draft, app.applied
	tpl := template_settings()
	section("Environment", em)
	if ui.card("", id = "###environment") {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = "###env_row") {
			chosen := d.desktop
			if ui.segmented("###desktop", DESKTOPS[:], &chosen) {
				s := d
				s.desktop = chosen
				draft_set(app, s)
			}
			changed_dot("env_dot", d.desktop != a.desktop, em)
			ui.spacer(ui.fill())
			if d.desktop != tpl.desktop {
				if ui.button("env_template", "Back to the template", lucide.ROTATE_CCW, {face = .Link}).clicked {
					s := d
					s.desktop = tpl.desktop
					draft_set(app, s)
				}
			}
		}
		ui.spacer(ui.px(em * 0.7))
		weak(DESKTOP_ABOUT[d.desktop], "env_about")
		if d.desktop == tpl.desktop { weak("The template's choice.", "env_template_note") }
	}
	section("Session", em)
	if ui.list_card("###session") {
		if ui.card_row("###dark") {
			setting_words("dark", "Dark look", "Windows, menus and panels in dark colours.", d.dark != a.dark, em)
			v := d.dark
			if ui.toggle("###dark_toggle", "", &v) { s := d; s.dark = v; draft_set(app, s) }
		}
		changed := d.auto_login != a.auto_login || (d.auto_login && d.login_as != a.login_as)
		if ui.card_row("###login") {
			setting_words("login", "Log in by itself", "Opens one person's session at start, with no password.", changed, em)
			if d.auto_login {
				who := d.login_as
				if ui.segmented("###login_as", PEOPLE[:], &who) { s := d; s.login_as = who; draft_set(app, s) }
				ui.spacer(ui.px(em * 0.8))
			}
			v := d.auto_login
			if ui.toggle("###login_toggle", "", &v) { s := d; s.auto_login = v; draft_set(app, s) }
		}
		if ui.card_row("###lock") {
			setting_words("lock", "Screen lock", "Locks the session once the screen goes off.", d.lock_after != a.lock_after, em)
			v := d.lock_after
			if ui.segmented("###lock", LOCKS[:], &v) { s := d; s.lock_after = v; draft_set(app, s) }
		}
	}
}

history_page :: proc(app: ^App, em: f32) {
	page_head("History", "Each version stays until you free its space.", em)
	ui.spacer(ui.px(em * 1.2))
	if ui.list_card("###versions") {
		for v, i in app.history {
			if ui.card_row(fmt.tprintf("###version%d", i)) {
				ui.next({width = ui.px(em * 8.5), height = ui.children_sum(), axis = .Y})
				if ui.column(id = fmt.tprintf("###version_number%d", i)) {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("Version %d###version_title%d", v.number, i))
					weak(v.date, fmt.tprintf("version_date%d", i))
				}
				ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
				if ui.column(id = fmt.tprintf("###version_words%d", i)) {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###version_what%d", v.title, i))
					weak(v.detail, fmt.tprintf("version_detail%d", i))
				}
				if v.number == app.version {
					ui.pill(fmt.tprintf("running%d", i), app.apply.at_boot ? "At the next start" : "Running", lucide.CHECK, ui.hue(.Green))
				} else {
					ui.button(fmt.tprintf("version_back%d", i), "Go back to it", lucide.ROTATE_CCW, {size = .Small})
				}
			}
		}
	}
}

templates_page :: proc(app: ^App, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###templates_head") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label("Templates###templates_title")
		ui.button("save_template", "Save this system as a template", lucide.UPLOAD)
	}
	ui.spacer(ui.px(em * 1.2))
	for line in 0 ..< (len(TEMPLATES) + 2) / 3 {
		if line > 0 { ui.spacer(ui.px(em * 0.9)) }
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###gallery%d", line)) {
			for k in 0 ..< 3 {
				i := line * 3 + k
				if k > 0 { ui.spacer(ui.px(em * 0.9)) }
				if i < len(TEMPLATES) { template_card(i, em) }
			}
		}
	}
}

@(private = "file")
template_card :: proc(i: int, em: f32) {
	t := TEMPLATES[i]
	ui.next({width = ui.fill(), height = ui.children_sum()})
	if ui.card("", id = fmt.tprintf("###template%d", i)) {
				ui.next({width = ui.fill(), height = ui.px(em * 6.5), radius = em * 0.45, bg = colour(t.bottom), border = colour(t.top)})
				ui.build_box({.Draw_Background, .Draw_Border}, fmt.tprintf("###template_preview%d", i))
				ui.spacer(ui.px(em * 0.8))
				ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
				if ui.row(id = fmt.tprintf("###template_title_row%d", i)) {
					ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###template_title%d", t.title, i))
					if t.in_use { ui.spacer(ui.px(em * 0.6)); ui.pill(fmt.tprintf("in_use%d", i), "In use", "", ui.hue(.Green)) }
					if t.yours { ui.spacer(ui.px(em * 0.6)); ui.pill(fmt.tprintf("yours%d", i), "Yours", "", ui.hue(.Blue)) }
				}
				ui.spacer(ui.px(em * 0.35))
				weak(t.about, fmt.tprintf("template_about%d", i))
				ui.spacer(ui.px(em * 0.5))
				if ui.tags("weak") {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, font_size = math.round(em * 0.85)})
					ui.label(fmt.tprintf("%s###template_source%d", t.source, i))
				}
	}
}

settings_page :: proc(app: ^App, em: f32) {
	page_head("All settings", "Every option of the system, and who sets it.", em)
	ui.spacer(ui.px(em * 1.2))
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
	if ui.row(id = "###options") {
		ui.next({width = ui.px(em * 24), height = ui.children_sum(), axis = .Y})
		if ui.column(id = "###options_list") {
			ui.next({width = ui.fill(), height = ui.px(ui.control_height()), radius = em * 0.45})
			if ui.input_frame("###options_search") {
				ui.next({width = ui.px(em * 2), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center})
				ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.SEARCH + "###options_search_icon")
				ui.next({width = ui.fill(), height = ui.pct(1)})
				if ui.tags("bare") { ui.line_edit("###options_field", &app.options_search, {placeholder = "Search 21 304 options"}) }
			}
			ui.spacer(ui.px(em * 0.6))
			query := strings.to_lower(ui.line_edit_string(&app.options_search), context.temp_allocator)
			for o, i in OPTIONS {
				if query != "" && !strings.contains(o.path, query) { continue }
				ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 2.1))})
				if ui.button(fmt.tprintf("option%d", i), o.path, o = {face = .Row, selected = i == app.option, width = ui.fill(), left = true}).clicked { app.option = i }
			}
		}
		ui.spacer(ui.px(em * 1.2))
		o := OPTIONS[app.option]
		ui.next({width = ui.fill(), height = ui.children_sum()})
		if ui.card("", id = "###option_detail") {
			ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.2), text_pad = 0})
			ui.label(fmt.tprintf("%s###option_path", o.path))
			ui.spacer(ui.px(em * 0.4))
			weak(o.about, "option_about")
			ui.spacer(ui.px(em * 0.9))
			if ui.form_row("Type") { ui.label(fmt.tprintf("%s###option_type", o.type)) }
			if ui.form_row("Default") { ui.label(fmt.tprintf("%s###option_default", o.default)) }
			if ui.form_row("Value") { ui.label(fmt.tprintf("%s###option_value", o.value)) }
			section("Who sets it", em)
			if ui.list_card("###layers") {
				layer_row("you", "You", o.yours, o.yours != "", em)
				layer_row("template", "Family desktop", o.template, o.yours == "" && o.template != "", em)
				layer_row("nixos", "NixOS", o.default, o.yours == "" && o.template == "", em)
			}
		}
	}
}

@(private = "file")
layer_row :: proc(id, who, value: string, wins: bool, em: f32) {
	if ui.card_row(fmt.tprintf("###layer_%s", id)) {
		ui.next({width = ui.px(em * 9), height = ui.text_size(), text_pad = 0})
		ui.label(fmt.tprintf("%s###layer_who_%s", who, id))
		if ui.tags("weak") {
			ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
			ui.label(fmt.tprintf("%s###layer_value_%s", value == "" ? "—" : value, id))
		}
		if wins { ui.pill(fmt.tprintf("layer_wins_%s", id), "Wins", lucide.CHECK, ui.hue(.Green)) }
	}
}

// A page whose feature is not built yet: it says so, once.
later_page :: proc(app: ^App, em: f32) {
	page_head(PAGE_TITLES[app.page], "", em)
	ui.spacer(ui.px(em * 1.2))
	if ui.card("", id = "###later") {
		weak("This page comes with its feature: ROADMAP.md, \"The pages of settings\".", "later_words")
	}
}
