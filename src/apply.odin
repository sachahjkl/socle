package socle

// The draft, its changes against the applied version, and the apply: prepare, try, keep (src/md/features/apply.md).
// In the demo, preparing is a clock that runs PREPARE_MS and the helper is this window: the stages and their order
// are the real ones.

import "core:fmt"
import "core:strings"
import lucide "gt:lucide"
import "gt:ui"

PREPARE_MS  :: 5200.0
KEEP_MS     :: 60000.0
DOWNLOAD_MB :: 640
PARTS       :: 52

REVIEW_VIEW :: "review"
KEEP_VIEW   :: "keep"

// A change of the draft, in words: the page it belongs to and what it does.
Change :: struct {
	page:    string,
	text:    string,
	restart: bool,   // the session restarts when it applies
}

Stage :: enum { Idle, Preparing, Trying }

Apply :: struct {
	stage:      Stage,
	now:        int,     // the review's choice: 0 now (try, then keep), 1 at the next start
	started_ms: f64,     // the stage's start, on the window's clock
	at_boot:    bool,    // the applied version waits for the next start
}

// The changes, made again each time the draft changes (never in a frame: the bar and the review read the list).
changes_update :: proc(app: ^App) {
	for c in app.changes { delete(c.text) }
	clear(&app.changes)
	d, a := &app.draft, &app.applied
	if d.desktop != a.desktop {
		append(&app.changes, Change{"Desktop", fmt.aprintf("Environment: %s, in place of %s", DESKTOPS[d.desktop], DESKTOPS[a.desktop]), true})
	}
	if d.dark != a.dark { append(&app.changes, Change{"Desktop", strings.clone(d.dark ? "Dark look" : "Light look"), false}) }
	if d.auto_login != a.auto_login || (d.auto_login && d.login_as != a.login_as) {
		text := d.auto_login ? fmt.aprintf("Log in by itself as %s", PEOPLE[d.login_as]) : strings.clone("Ask every person's password at start")
		append(&app.changes, Change{"Desktop", text, false})
	}
	if d.lock_after != a.lock_after { append(&app.changes, Change{"Desktop", fmt.aprintf("Lock the screen: %s", LOCKS[d.lock_after]), false}) }
	for p, i in CATALOGUE {
		if d.installed[i] == a.installed[i] { continue }
		text: string
		switch {
		case d.installed[i]:  text = fmt.aprintf("Add %s for everyone", p.name)
		case p.template:      text = fmt.aprintf("Remove %s, which the template adds", p.name)
		case:                 text = fmt.aprintf("Remove %s", p.name)
		}
		append(&app.changes, Change{"Apps", text, false})
	}
}

changes_restart :: proc(app: ^App) -> bool {
	for c in app.changes { if c.restart { return true } }
	return false
}

draft_set :: proc(app: ^App, s: Settings) {
	app.draft = s
	changes_update(app)
}

draft_discard :: proc(app: ^App) { draft_set(app, app.applied) }

// The review accepted: the stage that prepares the new system.
apply_start :: proc(app: ^App) {
	app.apply = {stage = .Preparing, now = app.apply.now, started_ms = ui.now_ms()}
}

// How far preparing is, 0..1.
apply_progress :: proc(app: ^App) -> f32 {
	return clamp(f32((ui.now_ms() - app.apply.started_ms) / PREPARE_MS), 0, 1)
}

// What moves with the clock: the end of preparing, the countdown of a try. Called before each build.
apply_step :: proc(app: ^App) {
	switch app.apply.stage {
	case .Idle:
	case .Preparing:
		ui.keep_animating()
		if apply_progress(app) < 1 { return }
		if app.apply.now == 1 {
			apply_record(app, true)
			return
		}
		app.apply.stage, app.apply.started_ms = .Trying, ui.now_ms()
		ui.view_open(ui.state_views(&app.main.state), KEEP_VIEW, app)
	case .Trying:
		ui.keep_animating()
		if ui.now_ms() - app.apply.started_ms >= KEEP_MS { apply_revert(app) }
	}
}

// The new version kept (or set for the next start): it is the applied one, and the history's first.
apply_record :: proc(app: ^App, at_boot: bool) {
	app.version += 1
	title := len(app.changes) > 0 ? app.changes[0].text : "Settings"
	pages := make([dynamic]string, context.temp_allocator)
	for c in app.changes {
		known := false
		for p in pages { known ||= p == c.page }
		if !known { append(&pages, c.page) }
	}
	detail := fmt.aprintf("%s · %d changes · %d MB", strings.join(pages[:], ", ", context.temp_allocator), len(app.changes), DOWNLOAD_MB)
	inject_at(&app.history, 0, Version{app.version, "Today, 10:41", strings.clone(title), detail, false})
	app.applied = app.draft
	app.apply = {stage = .Idle, now = app.apply.now, at_boot = at_boot}
	changes_update(app)
	if at_boot {
		ui.announce(&app.announcer, .Good, fmt.tprintf("Version %d is ready", app.version), "It starts at the next start of the machine.")
	} else {
		ui.announce(&app.announcer, .Good, fmt.tprintf("Version %d kept", app.version))
	}
}

// The try not kept: the previous version runs again; the draft stays as it was.
apply_revert :: proc(app: ^App) {
	app.apply.stage = .Idle
	ui.announce(&app.announcer, .Info, fmt.tprintf("Back to version %d", app.version), "Your changes wait in the draft.")
}

views_register_all :: proc(app: ^App) {
	vs := ui.state_views(&app.main.state)
	ui.view_register(vs, REVIEW_VIEW, review_view, ui.View_Options{title = "Review the changes", icon = lucide.LIST_CHECKS, width_em = 34})
	ui.view_register(vs, KEEP_VIEW, keep_view, ui.View_Options{title = "Keep this version?", icon = lucide.SHIELD_CHECK, width_em = 28})
}

review_open :: proc(app: ^App) {
	app.apply.now = changes_restart(app) ? 1 : 0
	ui.view_open(ui.state_views(&app.main.state), REVIEW_VIEW, app)
}

@(private = "file")
review_view :: proc(v: ^ui.View, app: ^App) {
	em := ui.font_size()
	if ui.dialog_body("review_body") {
		for c, i in app.changes {
			ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 2)), axis = .X, cross = .Center})
			if ui.row(id = fmt.tprintf("###change%d", i)) {
				if ui.tags("weak") {
					ui.next({width = ui.px(em * 5.5), height = ui.pct(1), text_pad = 0})
					ui.label(fmt.tprintf("%s###change_page%d", c.page, i))
				}
				ui.next({width = ui.fill(), height = ui.pct(1), text_pad = 0})
				ui.label(fmt.tprintf("%s###change_text%d", c.text, i))
			}
			if i + 1 < len(app.changes) { ui.hline(ui.fill()) }
		}
		if changes_restart(app) {
			ui.spacer(ui.px(em * 0.8))
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
			if ui.well("###restart", pad = ui.INNER_PAD) {
				ui.next({width = ui.px(em * 1.6), height = ui.px(em * 1.4), font = ui.lucide_icons(), fg = ui.hue(.Yellow), text_pad = 0})
				ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.ALERT_TRIANGLE + "###restart_icon")
				ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
				if ui.column(id = "###restart_words") {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label("The session restarts###restart_title")
					if ui.tags("weak") {
						ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
						ui.label("A new desktop closes the open apps. Save your work first, or apply at the next start.###restart_note")
					}
				}
			}
		}
		ui.spacer(ui.px(em * 0.8))
		if ui.form_row("Apply") {
			whens := [2]string{"Now, on trial", "At the next start"}
			ui.segmented("###review_when", whens[:], &app.apply.now)
		}
	}
	if ui.dialog_buttons("review_buttons") {
		if ui.button("review_back", "Back").clicked { ui.view_end(v, ui.VIEW_CANCELLED) }
		if ui.button("review_go", "Prepare and apply", lucide.ARROW_RIGHT, {intent = .Primary}).clicked {
			ui.view_end(v, 0)
			apply_start(app)
		}
	}
}

@(private = "file")
keep_view :: proc(v: ^ui.View, app: ^App) {
	em := ui.font_size()
	left := max(0, KEEP_MS - (ui.now_ms() - app.apply.started_ms))
	if app.apply.stage != .Trying { ui.view_end(v, ui.VIEW_CANCELLED); return }
	if ui.dialog_body("keep_body") {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = "###keep_row") {
			ui.next({width = ui.px(em * 4.2), height = ui.px(em * 3.6), font_size = em * 2.6, text_align = .Center, fg = ui.color("accent"), text_pad = 0})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, fmt.tprintf("%d###keep_seconds", int(left / 1000) + 1))
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
			if ui.column(id = "###keep_words") {
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
				ui.label(fmt.tprintf("Version %d runs now.###keep_now", app.version + 1))
				if ui.tags("weak") {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
					ui.label(fmt.tprintf("If nobody answers, the system goes back to version %d by itself.###keep_note", app.version))
				}
			}
		}
		ui.spacer(ui.px(em * 0.7))
		ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 0.45))})
		ui.progress("###keep_left", f32(left / KEEP_MS))
	}
	if ui.dialog_buttons("keep_buttons") {
		if ui.button("keep_back", "Go back now", lucide.ROTATE_CCW).clicked {
			ui.view_end(v, ui.VIEW_CANCELLED)
			apply_revert(app)
		}
		if ui.button("keep_yes", "Keep", lucide.CHECK, {intent = .Primary}).clicked {
			ui.view_end(v, 0)
			apply_record(app, false)
		}
	}
}
