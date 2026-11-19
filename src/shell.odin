package socle

// The frame every page stands in: the title bar (the mark, the search, the window's buttons), the sidebar of the pages,
// the page, the bar of changes under it.

import "core:fmt"
import "core:math"
import host "gt:host"
import lucide "gt:lucide"
import "gt:ui"

NAV_GROUPS := [?]struct { title: string, pages: []Page }{
	{"", {.Overview}},
	{"System", {.Apps, .People, .Desktop, .Hardware, .Sound, .Network, .Printing, .Gaming, .Sharing, .Power}},
	{"Manage", {.Updates, .History, .Templates, .All_Settings}},
}

PAGE_TITLES := [Page]string{
	.Overview = "Overview", .Apps = "Apps", .People = "People", .Desktop = "Desktop", .Hardware = "Hardware",
	.Sound = "Sound", .Network = "Network", .Printing = "Printing", .Gaming = "Gaming", .Sharing = "Sharing",
	.Power = "Start and power", .Updates = "Updates", .History = "History", .Templates = "Templates",
	.All_Settings = "All settings",
}

PAGE_ICONS := [Page]string{
	.Overview = lucide.LAYOUT_DASHBOARD, .Apps = lucide.PACKAGE, .People = lucide.USERS, .Desktop = lucide.MONITOR,
	.Hardware = lucide.CPU, .Sound = lucide.VOLUME_2, .Network = lucide.WIFI, .Printing = lucide.PRINTER,
	.Gaming = lucide.GAMEPAD_2, .Sharing = lucide.SHARE_2, .Power = lucide.POWER, .Updates = lucide.REFRESH_CW,
	.History = lucide.HISTORY, .Templates = lucide.LAYOUT_GRID, .All_Settings = lucide.SLIDERS_HORIZONTAL,
}

build :: proc(h: ^host.Host, size: host.Vec2) {
	app := (^App)(h.user)
	em := ui.font_size()
	ui.next({width = ui.fill(), height = ui.fill(), axis = .Y})
	if ui.column(id = "###app") {
		top_bar(app, em)
		ui.next({width = ui.fill(), height = ui.fill(), axis = .X})
		if ui.row(id = "###body") {
			sidebar(app, em)
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
							page_build(app, em)
							ui.spacer(ui.px(em * 1.6))
						}
						ui.spacer(ui.px(em * 1.8))
					}
				}
				changes_bar(app, em)
			}
		}
	}
	ui.set_toast_area({{0, ui.dense(em * 2.8)}, {size.x, size.y - ui.dense(em * 3.6)}})
}

@(private = "file")
page_build :: proc(app: ^App, em: f32) {
	#partial switch app.page {
	case .Overview:     overview_page(app, em)
	case .Apps:         apps_page(app, em)
	case .Desktop:      desktop_page(app, em)
	case .History:      history_page(app, em)
	case .Templates:    templates_page(app, em)
	case .All_Settings: settings_page(app, em)
	case:               later_page(app, em)
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
			ui.search_launcher("###search", "Search settings, apps, actions", "Ctrl+K", tip = "Find a page, an app or any setting")
			ui.spacer(ui.fill())
			if ui.tags("weak") {
				ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
				ui.label(fmt.tprintf("%s  ·  version %d###where", HOST_NAME, app.version))
			}
			ui.spacer(ui.px(em * 0.8))
			ui.window_buttons()
		}
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
				for g, gi in NAV_GROUPS {
					if g.title != "" {
						ui.spacer(ui.px(em * 0.7))
						if ui.tags("weak") {
							ui.next({width = ui.fill(), height = ui.px(em * 1.6), font_size = math.round(em * 0.8), text_pad = em * 1.0})
							ui.label(fmt.tprintf("%s###group%d", g.title, gi))
						}
					}
					for p in g.pages {
						ui.next({width = ui.fill(), height = ui.px(em * 2.2), axis = .X})
						if ui.row(id = fmt.tprintf("###navrow%v", p)) {
							ui.spacer(ui.px(em * (0.6 - ui.ROW_FACE_INSET_EM)))
							sig := ui.button(fmt.tprintf("###nav%v", p), PAGE_TITLES[p], PAGE_ICONS[p], {face = .Row, selected = p == app.page, width = ui.fill(), left = true})
							if sig.clicked { app.page = p }
							ui.spacer(ui.px(em * (0.6 - ui.ROW_FACE_INSET_EM)))
						}
					}
				}
			}
		}
	}
}

// The bar of changes: shown while the draft differs from the applied version, or while an apply runs. It is the only
// place that says that changes wait (window.md).
@(private = "file")
changes_bar :: proc(app: ^App, em: f32) {
	preparing := app.apply.stage == .Preparing
	if len(app.changes) == 0 && !preparing { return }
	ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 3.4)), axis = .X, cross = .Center, radius = 0})
	if ui.row(.Center, {.Draw_Background, .Draw_Side_Top}, "###changes_bar") {
		ui.spacer(ui.px(em * 1.6))
		if preparing {
			k := apply_progress(app)
			ui.button("###changes_busy", "Preparing", o = {face = .Ghost, busy = true})
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.px(em * 16), height = ui.px(ui.dense(em * 0.45))})
			ui.progress("###changes_progress", k)
			ui.spacer(ui.px(em * 0.9))
			if ui.tags("weak") {
				ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
				ui.label(fmt.tprintf("%d of %d MB  ·  %d of %d parts###changes_numbers", int(k * DOWNLOAD_MB), DOWNLOAD_MB, int(k * PARTS), PARTS))
			}
			ui.spacer(ui.fill())
			if ui.button("changes_cancel", "Cancel").clicked { app.apply.stage = .Idle }
		} else {
			ui.dot("###changes_dot", em * 0.55, .Primary)
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
			ui.label(fmt.tprintf("%d %s###changes_count", len(app.changes), len(app.changes) == 1 ? "change" : "changes"))
			ui.spacer(ui.fill())
			if ui.button("changes_discard", "Discard", o = {face = .Ghost}).clicked { draft_discard(app) }
			ui.spacer(ui.px(em * 0.5))
			if ui.button("changes_review", "Review and apply", lucide.ARROW_RIGHT, {intent = .Primary}).clicked { review_open(app) }
		}
		ui.spacer(ui.px(em * 1.2))
	}
}
