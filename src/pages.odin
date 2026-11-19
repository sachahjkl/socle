package socle

// The pages. Each reads the values through value_at and the evaluation, and writes the draft through set_value,
// set_app or the layer's procedures: the list of changes is made again then, never in a frame.

import "core:encoding/json"
import "core:fmt"
import "core:hash"
import "core:math"
import "core:slice"
import "core:strings"
import "core:time"
import "gt:draw"
import lucide "gt:lucide"
import "gt:ui"

////////////////////////////////
// Parts

// A page's head: its title, and a line that says what the page is.
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
section :: proc(title: string, em: f32) {
	ui.spacer(ui.px(em * 1.5))
	if ui.tags("weak") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 0.82), text_pad = 0})
		ui.label(fmt.tprintf("%s###section_%s", strings.to_upper(title, context.temp_allocator), title))
	}
	ui.spacer(ui.px(em * 0.6))
}

// A line of words in the weak colour, wrapped at the room it has.
weak :: proc(text, id: string) {
	if ui.tags("weak") {
		ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
		ui.label(fmt.tprintf("%s###%s", text, id))
	}
}

// The mark of a value that the draft changes: a dot of the accent, nothing else (window.md).
changed_dot :: proc(id: string, on: bool, em: f32) {
	if !on { return }
	ui.spacer(ui.px(em * 0.5))
	// (a height of its own: a share of a row as tall as what is in it would be a height that measures itself)
	ui.next({width = ui.px(em * 0.5), height = ui.px(math.round(em * 1.3)), axis = .Y, cross = .Center})
	if ui.column(.Center, id = fmt.tprintf("###%s_slot", id)) { ui.dot(fmt.tprintf("###%s", id), em * 0.45, .Primary) }
}

// A setting's words in its card row: its title (and the changed mark), what it does; the caller's control follows at
// the right. (card_row's scope is the caller's: a helper that opened it would close it at its own return)
setting_words :: proc(id, title, about: string, changed: bool, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
	if ui.column(id = fmt.tprintf("###%s_words", id)) {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = fmt.tprintf("###%s_title_row", id)) {
			// (a long title gives way and is cut: the row's control stays in the card)
			ui.next({width = ui.text_size(0, 0), height = ui.text_size(), text_pad = 0})
			ui.label(fmt.tprintf("%s###%s_title", title, id))
			changed_dot(fmt.tprintf("%s_dot", id), changed, em)
		}
		if about != "" { weak(about, fmt.tprintf("%s_about", id)) }
	}
	ui.spacer(ui.px(em))
}

// "Changed" for a value: what the draft sets, against the committed layer.
changed :: proc(app: ^App, path: string) -> bool {
	p := steps(path)
	now, was := layer_get(app.draft, p), layer_get(app.committed, p)
	if now == nil && was == nil { return false }
	if now == nil || was == nil { return true }
	return !json_equal(now, was)
}

// A tile of colour with a letter, the colour from the name (the same name, the same colour).
letter_tile :: proc(id, name: string, em: f32) {
	h := hash.fnv32a(transmute([]u8)name)
	hue := f32(h % 360) / 360
	c := draw.hsv(hue, 0.45, 0.62)
	letter := len(name) > 0 ? strings.to_upper(name[:1], context.temp_allocator) : "?"
	ui.next({width = ui.px(em * 2.2), height = ui.px(em * 2.2), radius = em * 0.5, bg = c, fg = {1, 1, 1, 1}, text_align = .Center, font_size = math.round(em * 1.05), text_pad = 0})
	ui.build_box({.Draw_Background, .Draw_Text, .No_Text_Trunc}, fmt.tprintf("%s###%s", letter, id))
}

////////////////////////////////
// Before a system shows

loading_page :: proc(app: ^App, em: f32) {
	page_head("Reading the system", "", em)
	ui.spacer(ui.px(em * 1.2))
	ui.button("###loading", fmt.tprintf("Evaluating %s", app.folder), o = {face = .Ghost, busy = true})
}

failed_page :: proc(app: ^App, em: f32) {
	page_head("The system does not evaluate", app.folder, em)
	ui.spacer(ui.px(em * 1.2))
	note_well("failed", lucide.ALERT_TRIANGLE, .Red, "nix says", app.load_error, em)
	ui.spacer(ui.px(em))
	if ui.button("retry", "Read it again", lucide.REFRESH_CW, {busy = app.loading}).clicked { load_start(app) }
}

// The last evaluation failed but an earlier one shows: the pages work, the note says why.
failure_note :: proc(app: ^App, em: f32) {
	note_well("stale", lucide.ALERT_TRIANGLE, .Yellow, "The folder does not evaluate now", app.load_error, em)
	ui.spacer(ui.px(em * 1.2))
}

// No configuration of socle's in the folder: take the machine over from a template (helper init).
setup_page :: proc(app: ^App, em: f32) {
	page_head("socle does not manage this machine yet", "", em)
	ui.spacer(ui.px(em))
	weak(fmt.tprintf("Choose a system to start from. socle then writes %s: its settings, this machine's hardware and its people, in a folder of its own. Nothing changes until you apply.", app.folder), "setup_intro")
	section("Start from", em)
	refs := [?]string{"socle#family-desktop", "socle#gaming", "socle#developer", "socle#home-server", "socle#minimal"}
	titles := [?]string{"Family desktop", "Gaming machine", "Developer workstation", "Home server", "Minimal"}
	ui.segmented("###setup_template", titles[:], &app.setup_ref)
	section("This machine", em)
	note_well("setup_warn", lucide.ALERT_TRIANGLE, .Yellow, "socle takes over this machine's system",
		"Once you apply, the system comes from socle's folder, and the configuration you have now no longer applies. Keep a copy of it.", em)
	ui.spacer(ui.px(em * 0.8))
	ui.next({width = ui.fill(), height = ui.px(em * 2.1)})
	ui.toggle("###setup_sure", "I understand: socle manages this machine from now on", &app.setup_sure)
	ui.spacer(ui.px(em * 0.8))
	if ui.button("setup_go", "Take this machine over", lucide.ARROW_RIGHT, {intent = .Primary, disabled = !app.setup_sure}).clicked {
		setup_start(app, refs[app.setup_ref])
	}
}

////////////////////////////////
// Overview

overview_page :: proc(app: ^App, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###overview_head") {
		ui.next({width = ui.text_size(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label(fmt.tprintf("%s###host", app.host))
		if app.info != nil && app.info.template_title != "" {
			ui.spacer(ui.px(em * 0.9))
			ui.pill("template", app.info.template_title, lucide.LAYOUT_GRID, ui.color("accent"))
		}
		ui.spacer(ui.px(em * 0.9))
		if ui.tags("weak") {
			ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
			running := running_generation(app)
			line := app.info != nil ? fmt.tprintf("NixOS %s", app.info.release) : ""
			if running != nil { line = fmt.tprintf("Version %d, applied %s  ·  %s", running.number, when_words(running.date), line) }
			ui.label(fmt.tprintf("%s###applied", line))
		}
	}
	ui.spacer(ui.px(em * 1.2))
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
	if ui.row(id = "###status") {
		waiting := waiting_generation(app)
		switch {
		case len(app.changes) > 0:
			status_card("running", fmt.tprintf("%d %s wait", len(app.changes), len(app.changes) == 1 ? "change" : "changes"), "Review them in the bar under the page.", lucide.CIRCLE_DOT, .Accent, "", em)
		case waiting != nil:
			status_card("running", fmt.tprintf("Version %d waits for the next start", waiting.number), "Restart the machine to run it.", lucide.POWER, .Yellow, "", em)
		case:
			status_card("running", "Running your settings", "What the pages show is what runs.", lucide.CHECK_CIRCLE, .Green, "", em)
		}
		ui.spacer(ui.px(em * 0.75))
		if status_card("updates", "Sources", fmt.tprintf("Software catalogue of %s.", date_words(app.lock_now["nixpkgs"])), lucide.REFRESH_CW, .Yellow, "Look for updates", em) {
			app.page = .Updates
			updates_start(app)
		}
		ui.spacer(ui.px(em * 0.75))
		status_card("space", fmt.tprintf("%d versions kept", len(app.generations)), "Each one can run again from the history.", lucide.HISTORY, .Blue, "", em)
	}
	section("Your system", em)
	tiles := make([dynamic][3]string, context.temp_allocator)   // page, title, text
	append(&tiles, [3]string{"desktop", "Desktop", fmt.tprintf("%s, %s", desktop_title(text_at(app, "socle.desktop.environment")), bool_at(app, "socle.desktop.dark") ? "dark" : "light")})
	append(&tiles, [3]string{"apps", "Apps", fmt.tprintf("%d for everyone", apps_count(app))})
	append(&tiles, [3]string{"people", "People", people_words(app)})
	if app.info != nil {
		for def in app.info.pages {
			own := false
			for o in OWN_PAGES { own ||= o == def.id }
			if own || len(tiles) >= 8 { continue }
			on := 0
			for path in def.options { if bool_of(value_at(app, path)) { on += 1 } }
			append(&tiles, [3]string{def.id, def.title, fmt.tprintf("%d of %d on", on, len(def.options))})
		}
	}
	for line in 0 ..< (len(tiles) + 3) / 4 {
		if line > 0 { ui.spacer(ui.px(em * 0.75)) }
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###tiles%d", line)) {
			for k in 0 ..< 4 {
				i := line * 4 + k
				if k > 0 { ui.spacer(ui.px(em * 0.75)) }
				ui.next({width = ui.fill(), height = ui.children_sum()})
				if i >= len(tiles) { ui.spacer(ui.fill()); continue }
				t := tiles[i]
				icon := icon_named(t[0])
				if ui.card(t[1], icon, fmt.tprintf("###tile_%s", t[0])) {
					weak(t[2], fmt.tprintf("tile_text_%s", t[0]))
				}
			}
		}
	}
	section("Recent versions", em)
	if ui.list_card("###recent") {
		for g, i in app.generations[:min(3, len(app.generations))] {
			if ui.card_row(fmt.tprintf("###recent%d", i)) {
				if ui.tags("weak") {
					ui.next({width = ui.px(em * 9), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###recent_date%d", when_words(g.date), i))
				}
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###recent_title%d", generation_title(g), i))
				if ui.tags("weak") {
					ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("Version %d###recent_version%d", g.number, i))
				}
			}
		}
	}
}

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

running_generation :: proc(app: ^App) -> ^Generation {
	for &g in app.generations { if g.running { return &g } }
	return nil
}

// A version that is the default but does not run: it starts at the next start.
waiting_generation :: proc(app: ^App) -> ^Generation {
	for &g in app.generations { if g.default_ && !g.running { return &g } }
	return nil
}

generation_title :: proc(g: Generation) -> string {
	if g.title != "" { return g.title }
	if g.revision == "" { return "Made outside socle" }
	return "Made by socle"
}

when_words :: proc(t: time.Time) -> string {
	if time.time_to_unix(t) == 0 { return "" }
	return date_words(time.time_to_unix(t))
}

apps_count :: proc(app: ^App) -> (n: int) {
	if app.info == nil { return }
	packages, _ := at(app.info.effective, {"packages"}).(json.Object)
	seen := make(map[string]bool, context.temp_allocator)
	for k in packages { seen[k] = true }
	if mine, ok := layer_get(app.draft, {"socle", "packages"}).(json.Object); ok { for k in mine { seen[k] = true } }
	for k in seen { if app_on(app, k) { n += 1 } }
	return
}

people_logins :: proc(app: ^App) -> []string {
	out := make([dynamic]string, context.temp_allocator)
	seen := make(map[string]bool, context.temp_allocator)
	if app.info != nil {
		if people, ok := at(app.info.effective, {"people"}).(json.Object); ok { for k in people { seen[k] = true } }
	}
	if mine, ok := layer_get(app.draft, {"socle", "people"}).(json.Object); ok { for k in mine { seen[k] = true } }
	for k in seen { append(&out, k) }
	slice.sort(out[:])
	return out[:]
}

people_words :: proc(app: ^App) -> string {
	names := make([dynamic]string, context.temp_allocator)
	for l in people_logins(app) { append(&names, person_title(app, l)) }
	return len(names) == 0 ? "Nobody yet" : strings.join(names[:], ", ", context.temp_allocator)
}

////////////////////////////////
// Apps

apps_page :: proc(app: ^App, em: f32) {
	logins := people_logins(app)
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###apps_head") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label("Apps###apps_title")
		audiences := make([dynamic]string, context.temp_allocator)
		append(&audiences, "For everyone")
		for l in logins { append(&audiences, person_title(app, l)) }
		if app.audience >= len(audiences) { app.audience = 0 }
		ui.segmented("###audience", audiences[:], &app.audience)
	}
	who := app.audience > 0 ? logins[app.audience - 1] : ""
	ui.spacer(ui.px(em * 1.1))
	ui.next({width = ui.px(em * 24), height = ui.px(ui.control_height()), radius = em * 0.45})
	if ui.input_frame("###apps_search") {
		ui.next({width = ui.px(em * 2), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center})
		ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.SEARCH + "###apps_search_icon")
		ui.next({width = ui.fill(), height = ui.pct(1)})
		if ui.tags("bare") { ui.line_edit("###apps_field", &app.search, {placeholder = "Search the apps"}) }
	}
	ui.spacer(ui.px(em * 0.9))
	if app.info == nil { return }
	query := strings.to_lower(ui.line_edit_string(&app.search), context.temp_allocator)
	shown := 0
	if ui.list_card("###apps_list") {
		// (thirty apps: the whole catalogue is searched on its worker, apps.md)
		for p, i in app.info.popular {
			if query != "" && !strings.contains(strings.to_lower(p.name, context.temp_allocator), query) &&
			   !strings.contains(strings.to_lower(p.about, context.temp_allocator), query) &&
			   !strings.contains(strings.to_lower(p.category, context.temp_allocator), query) { continue }
			app_row(app, p, i, who, em)
			shown += 1
		}
	}
	if query == "" { return }
	section("Every package", em)
	if app.source == .Demo {
		weak("The demo searches its popular apps only: a real system searches every package of its Nixpkgs.", "apps_demo")
		return
	}
	index_need(app, &app.catalogue, false)
	index_search(app, &app.catalogue, query)
	switch app.catalogue.state {
	case .Absent, .Building:
		ui.button("###catalogue_busy", "Reading the catalogue of Nixpkgs: a minute the first time", o = {face = .Ghost, busy = true})
	case .Failed:
		note_well("catalogue", lucide.ALERT_TRIANGLE, .Red, "The catalogue cannot be read", app.catalogue.why, em)
	case .Ready:
		if app.catalogue.query != query || app.catalogue.answered != app.catalogue.asked {
			ui.button("###catalogue_searching", "Searching", o = {face = .Ghost, busy = true})
			return
		}
		if len(app.catalogue.hits) == 0 { weak("No package says that.", "catalogue_none"); return }
		if ui.list_card("###catalogue_hits") {
			for e, i in app.catalogue.hits {
				popular := false
				for p in app.info.popular { popular ||= p.attr == e.key }
				if popular { continue }
				package_row(app, e, i, who, em)
			}
		}
	}
}

// A package of the whole catalogue: its attribute, its version, its description, Add or Remove.
@(private = "file")
package_row :: proc(app: ^App, e: Entry, i: int, who: string, em: f32) {
	path := who == "" ? fmt.tprintf("socle.packages.%s", e.key) : fmt.tprintf("socle.people.%s.packages.%s", who, e.key)
	on := who == "" ? app_on(app, e.key) : bool_at(app, path)
	if ui.card_row(fmt.tprintf("###package%d", i)) {
		letter_tile(fmt.tprintf("package_tile%d", i), e.key, em)
		ui.spacer(ui.px(em * 0.9))
		setting_words(fmt.tprintf("package_%d", i), e.key, e.description, changed(app, path), em)
		if ui.tags("weak") {
			ui.next({width = ui.px(em * 6.5), height = ui.text_size(), text_pad = 0, text_align = .Right})
			ui.label(fmt.tprintf("%s###package_version%d", e.version, i))
		}
		ui.spacer(ui.px(em * 0.9))
		ui.next({width = ui.px(em * 7.5)})
		if ui.button(fmt.tprintf("package_act%d", i), on ? "Added" : "Add", on ? lucide.CHECK : lucide.PLUS, {size = .Small}).clicked {
			if on { reset_value(app, path) } else { set_bool(app, path, true) }
		}
	}
}

@(private = "file")
app_row :: proc(app: ^App, p: Popular, i: int, who: string, em: f32) {
	path := who == "" ? fmt.tprintf("socle.packages.%s", p.attr) : fmt.tprintf("socle.people.%s.packages.%s", who, p.attr)
	on := who == "" ? app_on(app, p.attr) : bool_at(app, path)
	from_template := who == "" && app_from_template(app, p.attr)
	if ui.card_row(fmt.tprintf("###app%d", i)) {
		letter_tile(fmt.tprintf("app_tile%d", i), p.name, em)
		ui.spacer(ui.px(em * 0.9))
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
		if ui.column(id = fmt.tprintf("###app_words%d", i)) {
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
			if ui.row(id = fmt.tprintf("###app_title_row%d", i)) {
				ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###app_name%d", p.name, i))
				changed_dot(fmt.tprintf("app_dot%d", i), changed(app, path), em)
				if p.unfree {
					ui.spacer(ui.px(em * 0.6))
					ui.pill(fmt.tprintf("app_unfree%d", i), "Not free", "", ui.hue(.Yellow))
				}
			}
			about := p.about
			if from_template && !on { about = "From the template, removed by you" }
			weak(about, fmt.tprintf("app_about%d", i))
		}
		if ui.tags("weak") {
			ui.next({width = ui.px(em * 6.5), height = ui.text_size(), text_pad = 0, text_align = .Right})
			ui.label(fmt.tprintf("%s###app_version%d", p.version, i))
		}
		ui.spacer(ui.px(em * 0.9))
		ui.next({width = ui.px(em * 7.5)})
		label, icon := "Add", lucide.PLUS
		switch {
		case on && from_template: label, icon = "Remove", lucide.TRASH_2
		case on:                  label, icon = "Added", lucide.CHECK
		case from_template:       label, icon = "Put back", lucide.ROTATE_CCW
		}
		if ui.button(fmt.tprintf("app_act%d", i), label, icon, {size = .Small, face = label == "Put back" ? .Ghost : nil}).clicked {
			if who == "" { set_app(app, p, !on) } else if on { reset_value(app, path) } else { set_bool(app, path, true) }
		}
	}
}

////////////////////////////////
// Desktop

DESKTOP_IDS    := [?]string{"plasma", "gnome", "cosmic", "none"}
DESKTOP_NAMES  := [?]string{"Plasma", "GNOME", "COSMIC", "None"}
DESKTOP_ABOUT  := [?]string{
	"KDE's desktop: a panel at the bottom, windows as on most computers, every detail can be changed.",
	"A calm desktop: one bar at the top, the apps and the windows in one overview.",
	"System76's desktop: windows that tile by themselves, or float.",
	"No desktop: a console, for a server.",
}
LOCK_IDS   := [?]string{"never", "5", "15"}
LOCK_NAMES := [?]string{"Never", "5 minutes", "15 minutes"}

desktop_page :: proc(app: ^App, em: f32) {
	page_head("Desktop", "What people see after they log in.", em)
	section("Environment", em)
	env := text_at(app, "socle.desktop.environment")
	if ui.card("", id = "###environment") {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = "###env_row") {
			chosen := 0
			for id, i in DESKTOP_IDS { if id == env { chosen = i } }
			if ui.segmented("###desktop", DESKTOP_NAMES[:], &chosen) { set_text(app, "socle.desktop.environment", DESKTOP_IDS[chosen]) }
			changed_dot("env_dot", changed(app, "socle.desktop.environment"), em)
			ui.spacer(ui.fill())
			if draft_sets(app, "socle.desktop.environment") && template_at(app, "socle.desktop.environment") != nil {
				if ui.button("env_template", "Back to the template", lucide.ROTATE_CCW, {face = .Link}).clicked { reset_value(app, "socle.desktop.environment") }
			}
		}
		ui.spacer(ui.px(em * 0.7))
		for id, i in DESKTOP_IDS { if id == env { weak(DESKTOP_ABOUT[i], "env_about") } }
		if !draft_sets(app, "socle.desktop.environment") && template_at(app, "socle.desktop.environment") != nil { weak("The template's choice.", "env_template_note") }
	}
	section("Session", em)
	if ui.list_card("###session") {
		if ui.card_row("###dark") {
			setting_words("dark", "Dark look", "Windows, menus and panels in dark colours.", changed(app, "socle.desktop.dark"), em)
			v := bool_at(app, "socle.desktop.dark")
			if ui.toggle("###dark_toggle", "", &v) { set_bool(app, "socle.desktop.dark", v) }
		}
		if ui.card_row("###login") {
			changed_login := changed(app, "socle.desktop.autoLogin.enable") || changed(app, "socle.desktop.autoLogin.user")
			setting_words("login", "Log in by itself", "Opens one person's session at start, with no password.", changed_login, em)
			on := bool_at(app, "socle.desktop.autoLogin.enable")
			logins := people_logins(app)
			if on && len(logins) > 0 {
				user := text_at(app, "socle.desktop.autoLogin.user")
				who := 0
				names := make([dynamic]string, context.temp_allocator)
				for l, i in logins {
					append(&names, person_title(app, l))
					if l == user { who = i }
				}
				if ui.segmented("###login_as", names[:], &who) { set_text(app, "socle.desktop.autoLogin.user", logins[who]) }
				ui.spacer(ui.px(em * 0.8))
			}
			v := on
			if ui.toggle("###login_toggle", "", &v) {
				set_bool(app, "socle.desktop.autoLogin.enable", v)
				if v && text_at(app, "socle.desktop.autoLogin.user") == "" && len(logins) > 0 { set_text(app, "socle.desktop.autoLogin.user", logins[0]) }
			}
		}
		if ui.card_row("###lock") {
			setting_words("lock", "Screen lock", "Locks the session once the screen goes off.", changed(app, "socle.desktop.lockAfter"), em)
			lock := text_at(app, "socle.desktop.lockAfter")
			v := 0
			for id, i in LOCK_IDS { if id == lock { v = i } }
			if ui.segmented("###lock", LOCK_NAMES[:], &v) { set_text(app, "socle.desktop.lockAfter", LOCK_IDS[v]) }
		}
	}
}

////////////////////////////////
// People

people_page :: proc(app: ^App, em: f32) {
	page_head("People", "An account each; an administrator applies the changes.", em)
	ui.spacer(ui.px(em * 1.2))
	logins := people_logins(app)
	if ui.list_card("###people") {
		for l, i in logins {
			if ui.card_row(fmt.tprintf("###person%d", i)) {
				letter_tile(fmt.tprintf("person_tile%d", i), person_title(app, l), em)
				ui.spacer(ui.px(em * 0.9))
				admin_path := fmt.tprintf("socle.people.%s.admin", l)
				setting_words(fmt.tprintf("person_%d", i), person_title(app, l), fmt.tprintf("Login: %s", l), changed(app, fmt.tprintf("socle.people.%s", l)) || changed(app, admin_path), em)
				if ui.tags("weak") {
					ui.next({width = ui.text_size(0, 0), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("Administrator###person_admin_words%d", i))
				}
				ui.spacer(ui.px(em * 0.6))
				v := bool_at(app, admin_path)
				if ui.toggle(fmt.tprintf("###person_admin%d", i), "", &v) { set_bool(app, admin_path, v) }
				if draft_sets(app, fmt.tprintf("socle.people.%s.description", l)) {
					ui.spacer(ui.px(em * 0.6))
					if ui.button(fmt.tprintf("person_remove%d", i), icon = lucide.TRASH_2, o = {tip = "Remove this account"}).clicked {
						reset_value(app, fmt.tprintf("socle.people.%s", l))
					}
				}
			}
		}
	}
	section("Add a person", em)
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###add_person") {
		ui.next({width = ui.px(em * 16), height = ui.px(ui.control_height())})
		ui.line_edit("###new_login", &app.new_person, {placeholder = "A login: lowercase letters"})
		ui.spacer(ui.px(em * 0.6))
		login := strings.to_lower(strings.trim_space(ui.line_edit_string(&app.new_person)), context.temp_allocator)
		valid := len(login) > 0 && len(login) <= 32
		for c in login { valid &&= (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_' }
		if ui.button("person_add", "Add", lucide.PLUS, {disabled = !valid}).clicked {
			set_text(app, fmt.tprintf("socle.people.%s.description", login), login)
			ui.line_edit_set(&app.new_person, "")
		}
	}
	weak("A new account has no password: its owner sets one at the first login, or an administrator with passwd.", "people_note")
}

////////////////////////////////
// A feature's page, made from its options' declarations

feature_page :: proc(app: ^App, em: f32) {
	if app.info == nil { return }
	def: Page_Def
	found := false
	for p in app.info.pages { if p.id == app.feature { def, found = p, true } }
	if !found { app.page = .Overview; return }
	page_head(def.title, "", em)
	ui.spacer(ui.px(em * 1.2))
	if ui.list_card("###feature") {
		for path, i in def.options { option_row(app, path, i, em) }
	}
}

// One option as a row: its words from its description, its control from its type, its reset when the person set it.
option_row :: proc(app: ^App, path: string, i: int, em: f32) {
	f, known := app.info.facts[path]
	if !known { return }
	if ui.card_row(fmt.tprintf("###option%d", i)) {
		about := strings.trim_space(f.description)
		if nl := strings.index_byte(about, '\n'); nl > 0 && nl < len(about) - 1 { about = about[:nl] }
		setting_words(fmt.tprintf("option_%d", i), description_title(f.description), path, changed(app, path), em)
		if draft_sets(app, path) {
			if ui.button(fmt.tprintf("option_reset%d", i), "Reset", lucide.ROTATE_CCW, {face = .Link}).clicked { reset_value(app, path) }
			ui.spacer(ui.px(em * 0.6))
		}
		v := value_at(app, path)
		switch f.type {
		case "bool":
			b := bool_of(v)
			if ui.toggle(fmt.tprintf("###option_toggle%d", i), "", &b) { set_bool(app, path, b) }
		case "enum":
			if len(f.enums) > 0 && len(f.enums) <= 5 {
				k := 0
				for e, j in f.enums { if e == str(v) { k = j } }
				if ui.segmented(fmt.tprintf("###option_enum%d", i), f.enums, &k) { set_text(app, path, f.enums[k]) }
			} else {
				weak(value_words(v), fmt.tprintf("option_value%d", i))
			}
		case "int", "ints.between", "ints.positive", "ints.unsigned":
			n := int(num(v))
			if ui.number(fmt.tprintf("###option_number%d", i), &n, lo = 0, hi = 1000) { set_value(app, path, json.Integer(n)) }
		case:
			if ui.tags("weak") {
				ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###option_value%d", value_words(v), i))
			}
		}
	}
}

////////////////////////////////
// Updates

updates_page :: proc(app: ^App, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
	if ui.row(id = "###updates_head") {
		ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.55), text_pad = 0})
		ui.label("Updates###updates_title")
		if ui.button("updates_look", "Look for updates", lucide.REFRESH_CW, {busy = app.updating}).clicked { updates_start(app) }
	}
	ui.spacer(ui.px(em * 0.6))
	weak("A newer source is a change like any other: it waits in the bar, and the review shows it before it applies.", "updates_intro")
	section("Sources", em)
	names := make([dynamic]string, context.temp_allocator)
	for n in app.lock_now { append(&names, n) }
	slice.sort(names[:])
	if ui.list_card("###sources") {
		for n, i in names {
			if ui.card_row(fmt.tprintf("###source%d", i)) {
				was := app.lock_committed[n]
				now := app.lock_now[n]
				setting_words(fmt.tprintf("source_%d", i), input_title(n), n, was != now, em)
				if ui.tags("weak") {
					ui.next({width = ui.text_size(0, 0), height = ui.text_size(), text_pad = 0})
					ui.label(was != now ? fmt.tprintf("%s, in place of %s###source_date%d", date_words(now), date_words(was), i) : fmt.tprintf("%s###source_date%d", date_words(now), i))
				}
			}
		}
	}
}

////////////////////////////////
// History

history_page :: proc(app: ^App, em: f32) {
	page_head("History", "Each version stays until you free its space.", em)
	ui.spacer(ui.px(em * 1.2))
	if len(app.generations) == 0 { weak("This machine has no version of its system yet.", "history_none"); return }
	if ui.list_card("###versions") {
		for g, i in app.generations {
			if ui.card_row(fmt.tprintf("###version%d", i)) {
				ui.next({width = ui.px(em * 8.5), height = ui.children_sum(), axis = .Y})
				if ui.column(id = fmt.tprintf("###version_number%d", i)) {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("Version %d###version_title%d", g.number, i))
					weak(when_words(g.date), fmt.tprintf("version_date%d", i))
				}
				ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
				if ui.column(id = fmt.tprintf("###version_words%d", i)) {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###version_what%d", generation_title(g), i))
					if g.revision == "" { weak("Made by nixos-rebuild or another tool: no settings to compare.", fmt.tprintf("version_detail%d", i)) }
				}
				switch {
				case g.running:
					ui.pill(fmt.tprintf("running%d", i), "Running", lucide.CHECK, ui.hue(.Green))
				case g.default_:
					ui.pill(fmt.tprintf("waiting%d", i), "At the next start", lucide.POWER, ui.hue(.Yellow))
				case:
					if ui.button(fmt.tprintf("version_back%d", i), "Go back to it", lucide.ROTATE_CCW, {size = .Small, disabled = apply_busy(app)}).clicked {
						apply_go_back(app, g)
					}
				}
			}
		}
	}
}

////////////////////////////////
// Templates

templates_page :: proc(app: ^App, em: f32) {
	page_head("Templates", "The system you start from. Your own settings stay over it.", em)
	ui.spacer(ui.px(em * 1.2))
	if app.info == nil { return }
	current := layer_template(app.draft)
	gallery := app.info.gallery[:]
	for line in 0 ..< (len(gallery) + 2) / 3 {
		if line > 0 { ui.spacer(ui.px(em * 0.9)) }
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###gallery%d", line)) {
			for k in 0 ..< 3 {
				i := line * 3 + k
				if k > 0 { ui.spacer(ui.px(em * 0.9)) }
				ui.next({width = ui.fill(), height = ui.children_sum()})
				if i >= len(gallery) { ui.spacer(ui.fill()); continue }
				template_card(app, gallery[i], i, current, em)
			}
		}
	}
}

@(private = "file")
template_card :: proc(app: ^App, t: Gallery_Entry, i: int, current: string, em: f32) {
	if ui.card("", id = fmt.tprintf("###template%d", i)) {
		// (the blues and violets of the mark, one per template)
		h := hash.fnv32a(transmute([]u8)t.ref)
		hue := (200 + f32(h % 80)) / 360
		ui.next({width = ui.fill(), height = ui.px(em * 5.5), radius = em * 0.45, bg = draw.hsv(hue, 0.45, 0.42), border = draw.hsv(hue, 0.45, 0.28)})
		ui.build_box({.Draw_Background, .Draw_Border}, fmt.tprintf("###template_preview%d", i))
		ui.spacer(ui.px(em * 0.8))
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = fmt.tprintf("###template_title_row%d", i)) {
			ui.next({width = ui.text_size(), height = ui.text_size(), text_pad = 0})
			ui.label(fmt.tprintf("%s###template_title%d", t.title, i))
			if t.ref == current {
				ui.spacer(ui.px(em * 0.6))
				ui.pill(fmt.tprintf("in_use%d", i), t.ref == layer_template(app.committed) ? "In use" : "Chosen", "", ui.hue(.Green))
			}
		}
		ui.spacer(ui.px(em * 0.35))
		weak(t.description, fmt.tprintf("template_about%d", i))
		if t.parent != "" { weak(fmt.tprintf("Extends %s.", gallery_title(app, t.parent)), fmt.tprintf("template_parent%d", i)) }
		ui.spacer(ui.px(em * 0.6))
		if t.ref != current {
			if ui.button(fmt.tprintf("template_use%d", i), "Start from this one", o = {size = .Small}).clicked {
				layer_set_template(&app.draft, t.ref)
				draft_changed(app)
			}
		}
	}
}

////////////////////////////////
// All settings

settings_page :: proc(app: ^App, em: f32) {
	page_head("All settings", "Every option the pages show, and who sets it.", em)
	ui.spacer(ui.px(em * 1.2))
	if app.info == nil { return }
	paths := make([dynamic]string, context.temp_allocator)
	for p in app.info.facts { append(&paths, p) }
	slice.sort(paths[:])
	if app.option == "" && len(paths) > 0 { app.option = strings.clone(paths[0]) }
	ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
	if ui.row(id = "###options") {
		ui.next({width = ui.px(em * 22), height = ui.children_sum(), axis = .Y})
		if ui.column(id = "###options_list") {
			ui.next({width = ui.fill(), height = ui.px(ui.control_height()), radius = em * 0.45})
			if ui.input_frame("###options_search") {
				ui.next({width = ui.px(em * 2), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center})
				ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.SEARCH + "###options_search_icon")
				ui.next({width = ui.fill(), height = ui.pct(1)})
				if ui.tags("bare") { ui.line_edit("###options_field", &app.options_search, {placeholder = "Search the options"}) }
			}
			ui.spacer(ui.px(em * 0.6))
			query := strings.to_lower(ui.line_edit_string(&app.options_search), context.temp_allocator)
			every := query != "" && app.source == .Folder
			if every {
				// (every option of the system: its index, built once)
				index_need(app, &app.options_index, true)
				index_search(app, &app.options_index, query)
				#partial switch app.options_index.state {
				case .Absent, .Building: ui.button("###options_busy", "Reading every option: a minute the first time", o = {face = .Ghost, busy = true, size = .Small})
				case .Failed:            weak(app.options_index.why, "options_failed")
				}
			}
			if every && app.options_index.state == .Ready {
				for e, i in app.options_index.hits { option_line(app, e.key, i, em) }
			} else {
				for path, i in paths {
					if query != "" && !contains_fold(path, query) && !contains_fold(app.info.facts[path].description, query) { continue }
					option_line(app, path, i, em)
				}
			}
		}
		ui.spacer(ui.px(em * 1.2))
		ui.next({width = ui.fill(), height = ui.children_sum()})
		if ui.card("", id = "###option_detail") { option_detail(app, em) }
	}
}

@(private = "file")
option_line :: proc(app: ^App, path: string, i: int, em: f32) {
	ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 2.1))})
	if ui.button(fmt.tprintf("option%d", i), path, o = {face = .Row, selected = path == app.option, width = ui.fill(), left = true}).clicked {
		delete(app.option)
		app.option = strings.clone(path)
	}
}

// The option chosen: its words, its control (a page's option) or its value (any other), and the layers that set it.
@(private = "file")
option_detail :: proc(app: ^App, em: f32) {
	path := app.option
	f, known := app.info.facts[path]
	entry: Entry
	if !known {
		for e in app.options_index.entries { if e.key == path { entry = e; break } }
	}
	description := known ? f.description : entry.description
	ui.next({width = ui.fill(), height = ui.text_size(), font_size = math.round(em * 1.15), text_pad = 0})
	ui.label(fmt.tprintf("%s###option_path", path))
	ui.spacer(ui.px(em * 0.4))
	weak(strings.trim_space(description), "option_about")
	ui.spacer(ui.px(em * 0.6))
	mine := layer_get(app.draft, steps(path))
	tpl := template_at(app, path)
	if known {
		if ui.list_card("###option_edit") { option_row(app, path, 999, em) }
	} else {
		if ui.form_row("Type") { ui.label(fmt.tprintf("%s###option_type", entry.name)) }
		if ui.form_row("Default") { ui.label(fmt.tprintf("%s###option_default", entry.version != "" ? entry.version : "none")) }
		if ui.form_row("Value") {
			text, ready := option_value(app, path)
			if mine != nil { text, ready = value_words(mine), true }
			if ready {
				if entry.name == "boolean" {
					b := text == "true" || text == "on"
					if ui.toggle("###option_bool", "", &b) { set_bool(app, path, b) }
				} else {
					ui.label(fmt.tprintf("%s###option_value", text))
				}
			} else {
				ui.button("###option_reading", "Evaluating", o = {face = .Ghost, busy = true, size = .Small})
			}
		}
		if mine != nil {
			if ui.button("option_detail_reset", "Back to the system's value", lucide.ROTATE_CCW, {face = .Link}).clicked { reset_value(app, path) }
		}
	}
	section("Who sets it", em)
	machine := layer_get(app.machine, steps(path))
	if ui.list_card("###layers") {
		// (the machine's layer is above the person's: configuration.md, "The layers")
		layer_row("machine", "This machine", machine, machine != nil, em)
		layer_row("you", "You", mine, machine == nil && mine != nil, em)
		layer_row("template", app.info.template_title != "" ? app.info.template_title : "The template", tpl, machine == nil && mine == nil && tpl != nil, em)
		layer_row("nixos", "NixOS and its modules", known ? f.default : json.Value(json.String(entry.version)), machine == nil && mine == nil && tpl == nil, em)
	}
}

@(private = "file")
layer_row :: proc(id, who: string, value: json.Value, wins: bool, em: f32) {
	if ui.card_row(fmt.tprintf("###layer_%s", id)) {
		ui.next({width = ui.px(em * 11), height = ui.text_size(), text_pad = 0})
		ui.label(fmt.tprintf("%s###layer_who_%s", who, id))
		if ui.tags("weak") {
			ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
			ui.label(fmt.tprintf("%s###layer_value_%s", value == nil ? "—" : value_words(value), id))
		}
		if wins { ui.pill(fmt.tprintf("layer_wins_%s", id), "Wins", lucide.CHECK, ui.hue(.Green)) }
	}
}
