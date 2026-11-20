package socle

// The frame every page stands in: the title bar (the mark, the search, the machine), the sidebar of the pages (socle's
// own, and the features' pages the evaluation lists), the page, the bar of changes under it.

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import host "gt:host"
import lucide "gt:lucide"
import "gt:ui"

PAGE_TITLES := [Page]string{
	.Overview = "Overview", .Apps = "Apps", .People = "People", .Desktop = "Desktop", .Feature = "",
	.Updates = "Updates", .History = "History", .Templates = "Templates", .All_Settings = "All settings",
}

PAGE_ICONS := [Page]string{
	.Overview = lucide.LAYOUT_DASHBOARD, .Apps = lucide.PACKAGE, .People = lucide.USERS, .Desktop = lucide.MONITOR,
	.Feature = lucide.SLIDERS_HORIZONTAL, .Updates = lucide.REFRESH_CW, .History = lucide.HISTORY,
	.Templates = lucide.LAYOUT_GRID, .All_Settings = lucide.SLIDERS_HORIZONTAL,
}

// A Lucide icon by the name a feature gives (socle.ui.pages.<id>.icon).
icon_named :: proc(name: string) -> string {
	switch name {
	case "cpu":       return lucide.CPU
	case "volume-2":  return lucide.VOLUME_2
	case "wifi":      return lucide.WIFI
	case "printer":   return lucide.PRINTER
	case "gamepad-2": return lucide.GAMEPAD_2
	case "share-2":   return lucide.SHARE_2
	case "power":     return lucide.POWER
	case "monitor":   return lucide.MONITOR
	case "package":   return lucide.PACKAGE
	case "users":     return lucide.USERS
	}
	return lucide.SLIDERS_HORIZONTAL
}

// socle's own pages that a feature's page stands for: they have a page of their own.
OWN_PAGES :: [?]string{"apps", "desktop", "people"}

build :: proc(h: ^host.Host, size: host.Vec2) {
	app := (^App)(h.user)
	em := ui.font_size()
	if app.installer != nil {
		installer_build(app, em)
		ui.set_toast_area({{0, ui.dense(em * 2.8)}, {size.x, size.y - ui.dense(em * 3.6)}})
		return
	}
	// (in the build: what moves with the clock asks for its frames and its wakes here)
	apply_step(app)
	evaluator_step(app)
	ui.next({width = ui.fill(), height = ui.fill(), axis = .Y})
	if ui.column(id = "###app") {
		top_bar(app, em)
		ui.next({width = ui.fill(), height = ui.fill(), axis = .X})
		if ui.row(id = "###body") {
			ready := app.load == .Ready || (app.load == .Failed && app.info != nil)
			if ready { sidebar(app, em) }
			ui.next({width = ui.fill(), height = ui.fill(), axis = .Y})
			if ui.column(id = "###main") {
				ui.next({width = ui.fill(), height = ui.fill()})
				if ui.scroll_y("###page_scroll") {
					ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
					if ui.row(id = "###page_margin") {
						ui.spacer(ui.px(em * 1.8))
						ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
						if ui.column(id = "###page") {
							ui.spacer(ui.px(em * 1.4))
							switch {
							case app.load == .Absent:   setup_page(app, em)
							case !ready && app.load == .Failed: failed_page(app, em)
							case !ready:                loading_page(app, em)
							case:
								if app.load == .Failed { failure_note(app, em) }
								page_build(app, em)
							}
							ui.spacer(ui.px(em * 1.6))
						}
						ui.spacer(ui.px(em * 1.8))
					}
				}
				if ready {
					build_log_panel(app, em)
					changes_bar(app, em)
				}
			}
		}
	}
	ui.set_toast_area({{0, ui.dense(em * 2.8)}, {size.x, size.y - ui.dense(em * 3.6)}})
}

@(private = "file")
page_build :: proc(app: ^App, em: f32) {
	switch app.page {
	case .Overview:     overview_page(app, em)
	case .Apps:         apps_page(app, em)
	case .People:       people_page(app, em)
	case .Desktop:      desktop_page(app, em)
	case .Feature:      feature_page(app, em)
	case .Updates:      updates_page(app, em)
	case .History:      history_page(app, em)
	case .Templates:    templates_page(app, em)
	case .All_Settings: settings_page(app, em)
	}
}

@(private = "file")
top_bar :: proc(app: ^App, em: f32) {
	if ui.tags("bar") {
		ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 2.8)), radius = 0})
		if ui.title_bar("###top", {.Draw_Background, .Draw_Side_Bottom}) {
			ui.spacer(ui.px(em * 0.9))
			ui.next({width = ui.px(em * 1.5), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center, fg = ui.color("accent")})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.LAYERS_3 + "###mark")
			ui.spacer(ui.px(em * 0.35))
			ui.next({width = ui.text_size(), height = ui.pct(1), font_size = math.round(em * 1.05), text_pad = 0})
			ui.label("socle###brand")
			ui.spacer(ui.px(em * 1.4))
			ui.next({width = {kind = .Pixels, value = math.round(em * 22), strictness = 0, least = math.round(em * 10)}})
			if ui.search_launcher("###search", "Search settings, apps, actions", "Ctrl+K", tip = "Find a page, an app or any setting").clicked {
				app.page = .All_Settings
			}
			ui.spacer(ui.fill())
			if ui.tags("weak") {
				ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
				place := app.host
				if n := current_number(app); n > 0 { place = fmt.tprintf("%s  ·  version %d", app.host, n) }
				if app.source == .Demo { place = fmt.tprintf("%s  ·  demo", place) }
				ui.label(fmt.tprintf("%s###where", place))
			}
			ui.spacer(ui.px(em * 0.8))
			ui.window_buttons()
		}
	}
}

@(private = "file")
nav_line :: proc(app: ^App, id, title, icon: string, selected: bool, em: f32) -> bool {
	clicked := false
	ui.next({width = ui.fill(), height = ui.px(em * 2.2), axis = .X})
	if ui.row(id = fmt.tprintf("###navrow_%s", id)) {
		ui.spacer(ui.px(em * (0.6 - ui.ROW_FACE_INSET_EM)))
		clicked = ui.button(fmt.tprintf("nav_%s", id), title, icon, {face = .Row, selected = selected, width = ui.fill(), left = true}).clicked
		ui.spacer(ui.px(em * (0.6 - ui.ROW_FACE_INSET_EM)))
	}
	return clicked
}

@(private = "file")
nav_group :: proc(title: string, em: f32) {
	ui.spacer(ui.px(em * 0.7))
	if ui.tags("weak") {
		ui.next({width = ui.fill(), height = ui.px(em * 1.6), font_size = math.round(em * 0.8), text_pad = em * 1.0})
		ui.label(fmt.tprintf("%s###group_%s", title, title))
	}
}

@(private = "file")
sidebar :: proc(app: ^App, em: f32) {
	if ui.tags("bar") {
		ui.next({width = ui.px(em * 13.5), height = ui.fill(), axis = .Y, radius = 0})
		if ui.column(flags = {.Draw_Background, .Draw_Side_Right}, id = "###nav") {
			ui.next({width = ui.fill(), height = ui.fill()})
			if ui.strip("###nav_strip", {axes = {.Y}}) {
				ui.spacer(ui.px(em * 0.8))
				if nav_line(app, "Overview", "Overview", PAGE_ICONS[.Overview], app.page == .Overview, em) { app.page = .Overview }
				nav_group(app.target == .Home ? "Home" : "System", em)
				// (socle's own pages, where the target's evaluation lists them: a home has no people, no desktop)
				OWN := [3]struct { page: Page, id: string }{{.Apps, "apps"}, {.People, "people"}, {.Desktop, "desktop"}}
				for o in OWN {
					listed := app.info == nil
					if app.info != nil { for def in app.info.pages { listed ||= def.id == o.id } }
					if !listed { continue }
					if nav_line(app, fmt.tprintf("%v", o.page), PAGE_TITLES[o.page], PAGE_ICONS[o.page], app.page == o.page, em) { app.page = o.page }
				}
				if app.info != nil {
					for def in app.info.pages {
						own := false
						for o in OWN_PAGES { own ||= o == def.id }
						if own || def.group != "System" { continue }
						if nav_line(app, def.id, def.title, icon_named(def.icon), app.page == .Feature && app.feature == def.id, em) {
							app.page = .Feature
							delete(app.feature)
							app.feature = strings.clone(def.id)
						}
					}
				}
				nav_group("Manage", em)
				for p in ([]Page{.Updates, .History, .Templates, .All_Settings}) {
					if nav_line(app, fmt.tprintf("%v", p), PAGE_TITLES[p], PAGE_ICONS[p], app.page == p, em) { app.page = p }
				}
			}
		}
	}
}

// The bar of changes: shown while the draft differs from the applied version, or while an apply runs. It is the only
// place that says that changes wait (window.md).
@(private = "file")
changes_bar :: proc(app: ^App, em: f32) {
	stage := app.apply.stage
	if len(app.changes) == 0 && stage == .Idle && app.eval_error == "" { return }
	ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 3.4)), axis = .X, cross = .Center, radius = 0})
	if ui.row(.Center, {.Draw_Background, .Draw_Side_Top}, "###changes_bar") {
		ui.spacer(ui.px(em * 1.6))
		switch stage {
		case .Preparing:
			k := apply_fraction(app)
			ui.button("###changes_busy", "Preparing", o = {face = .Ghost, busy = true})
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.px(em * 14), height = ui.px(ui.dense(em * 0.45))})
			ui.progress("###changes_progress", k, app.source == .Folder && k == 0)
			ui.spacer(ui.px(em * 0.9))
			if ui.tags("weak") {
				ui.next({width = ui.fill(), height = ui.pct(1), text_pad = 0})
				ui.label(fmt.tprintf("%s###changes_numbers", progress_words(app, k)))
			}
			details_button(app, em)
		case .Starting:
			ui.button("###changes_busy", "Starting the new version", o = {face = .Ghost, busy = true})
			ui.spacer(ui.fill())
		case .Trying, .Finishing:
			ui.button("###changes_busy", "On trial", o = {face = .Ghost, busy = true})
			ui.spacer(ui.fill())
		case .Freeing:
			ui.button("###changes_busy", "Freeing space", o = {face = .Ghost, busy = true})
			ui.spacer(ui.fill())
		case .Idle:
			if app.eval_error != "" {
				ui.dot("###changes_dot", em * 0.55, .Danger)
			} else {
				ui.dot("###changes_dot", em * 0.55, .Primary)
			}
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
			ui.label(fmt.tprintf("%d %s###changes_count", len(app.changes), len(app.changes) == 1 ? "change" : "changes"))
			if app.evaluating {
				ui.spacer(ui.px(em * 0.9))
				ui.button("###changes_checking", "Checking", o = {face = .Ghost, busy = true, size = .Small})
			} else if app.eval_error != "" {
				ui.spacer(ui.px(em * 0.9))
				if ui.tags("weak") {
					ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
					ui.label("They do not evaluate: the review says why###changes_invalid")
				}
			}
			ui.spacer(ui.fill())
			// (the lines of a build that failed stay to be read: apply.md, "The build's details")
			if app.apply.failure != "" && len(app.apply.log.lines) > 0 {
				details_button(app, em)
				ui.spacer(ui.px(em * 0.5))
			}
			if ui.button("changes_discard", "Discard", o = {face = .Ghost}).clicked { draft_discard(app) }
			ui.spacer(ui.px(em * 0.5))
			if ui.button("changes_review", "Review and apply", lucide.ARROW_RIGHT, {intent = .Primary, disabled = len(app.changes) == 0}).clicked { review_open(app) }
		}
		ui.spacer(ui.px(em * 1.2))
	}
}

// The draft brought back to the committed layer, and the lock to the committed one.
draft_discard :: proc(app: ^App) {
	layer_destroy(&app.draft)
	app.draft = layer_clone(app.committed)
	draft_changed(app)
	if app.source != .Folder { return }
	// (socle's own files of the folder as its last commit has them: a template's link, the sources moved forward)
	Discard :: struct { app: ^App, folder: string }
	ui.task(&app.main.state, proc(d: rawptr) {
		x := (^Discard)(d)
		// (system.json too, before the folder is read again: the draft's save may not have ended, and both hold the
		// commit's values)
		_ = run({"git", "-C", x.folder, "checkout", "HEAD", "--", "flake.nix", "flake.lock", "socle/system.json"}, allocator = context.temp_allocator)
		inputs := join(x.folder, "socle", INPUTS_FILE)
		if run({"git", "-C", x.folder, "checkout", "HEAD", "--", "socle/inputs.json"}, allocator = context.temp_allocator).ok == false { _ = os.remove(inputs) }
	}, proc(d: rawptr, _: u64) {
		x := (^Discard)(d)
		load_start(x.app)
		delete(x.folder)
		free(x)
	}, new_clone(Discard{app = app, folder = strings.clone(app.folder)}), proc(d: rawptr) { free(d) })
}

// The build's lines unfolded above the bar, or folded.
@(private = "file")
details_button :: proc(app: ^App, em: f32) {
	l := &app.apply.log
	if ui.button("changes_details", "Details", l.open ? lucide.CHEVRON_DOWN : lucide.CHEVRON_UP, {face = .Ghost}).clicked { l.open = !l.open }
}

// The height of the build's lines unfolded, in ems, and the size of their text, of the font's.
@(private = "file") LOG_HEIGHT_EM :: 14
@(private = "file") LOG_TEXT :: 0.86

// The build's lines (apply.md, "The build's details"): a virtual list of the lines kept, which follows the end until the
// person scrolls up.
@(private = "file")
build_log_panel :: proc(app: ^App, em: f32) {
	l := &app.apply.log
	if !l.open { return }
	if app.apply.stage != .Preparing && !(app.apply.stage == .Idle && app.apply.failure != "" && len(l.lines) > 0) { return }
	// (sunk in a well: the page above and the bar below are not one surface with it)
	ui.next({width = ui.fill(), height = ui.px(math.round(em * LOG_HEIGHT_EM)), axis = .Y, radius = 0, bg = ui.color("well")})
	if ui.column(flags = {.Draw_Background, .Draw_Side_Top}, id = "###build_log_panel") {
		// (at the end at the last layout, or never laid out: the new lines are followed)
		at_end := true
		view := em * LOG_HEIGHT_EM
		if prev := ui.prev_box("###build_log"); prev != nil {
			at_end = prev.view_target.y + prev.size.y >= prev.view_bounds.y - em
			view = prev.size.y
		}
		size := math.round(em * LOG_TEXT)
		ui.next({width = ui.fill(), height = ui.fill()})
		if rows, ok := ui.vlist("###build_log", &l.vl, l.ids[:], ids_version = l.version); ok {
			for i in rows.first ..< rows.last {
				ui.next({width = ui.fill(), height = ui.px(math.round(size * 1.55)), font = ui.mono_font(), font_size = size, text_pad = math.round(em * 1.2)})
				b := ui.build_box({.Draw_Text}, ui.vlist_row_name(i))
				b.text = l.lines[i]
			}
		}
		// (after the build: the list's height counts the new lines then. A place past the end is not clamped, and a view
		// there builds no row)
		if at_end && l.shown != l.version {
			ui.vlist_scroll_to(&l.vl, max(0, ui.vlist_total(&l.vl) - view))
			l.shown = l.version
		}
	}
}

progress_words :: proc(app: ^App, k: f32) -> string {
	if app.source == .Demo {
		return fmt.tprintf("%d of 640 MB  ·  %d of 52 parts", int(k * 640), int(k * 52))
	}
	p := app.apply.progress
	parts := make([dynamic]string, context.temp_allocator)
	if p.bytes_expected > 0 { append(&parts, fmt.tprintf("%d of %d MB", p.bytes_done / 1_000_000, p.bytes_expected / 1_000_000)) }
	if p.paths_expected > 0 { append(&parts, fmt.tprintf("%d of %d downloaded", p.paths_done, p.paths_expected)) }
	if p.builds_expected > 0 { append(&parts, fmt.tprintf("%d of %d built", p.builds_done, p.builds_expected)) }
	if len(parts) == 0 { append(&parts, "Evaluating the system") }
	if p.doing != "" { append(&parts, short_doing(p.doing)) }
	return strings.join(parts[:], "  ·  ", context.temp_allocator)
}

// "building '/nix/store/…-firefox-145.0.drv'" -> "building firefox-145.0".
short_doing :: proc(s: string) -> string {
	out := s
	if at := strings.index(out, "/nix/store/"); at >= 0 {
		rest := out[at + len("/nix/store/"):]
		if dash := strings.index_byte(rest, '-'); dash >= 0 { rest = rest[dash + 1:] }
		rest = strings.trim_right(rest, "'\"")
		rest = strings.trim_suffix(rest, ".drv")
		out = fmt.tprintf("%s%s", out[:at], rest)
	}
	return strings.trim_space(strings.trim_right(out, "'"))
}
