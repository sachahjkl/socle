package socle

// The frame every page stands in: the title bar (the mark, the search, the machine), the sidebar of the pages (socle's
// own, and the features' pages the evaluation lists), the page, the bar of changes under it.

import "core:fmt"
import "core:math"
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
				if ready { changes_bar(app, em) }
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
				nav_group("System", em)
				for p in ([]Page{.Apps, .People, .Desktop}) {
					if nav_line(app, fmt.tprintf("%v", p), PAGE_TITLES[p], PAGE_ICONS[p], app.page == p, em) { app.page = p }
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
		case .Starting:
			ui.button("###changes_busy", "Starting the new version", o = {face = .Ghost, busy = true})
			ui.spacer(ui.fill())
		case .Trying, .Finishing:
			ui.button("###changes_busy", "On trial", o = {face = .Ghost, busy = true})
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
