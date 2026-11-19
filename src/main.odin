// socle: your whole system in one window. src/md/README.md says how it is built. This version is the window on a demo
// system (demo.odin): the pages, the draft and its review, the try and the keep, the history; it drives no Nix yet.
//   socle                     the window
//   socle --page=apps         a page first (overview, apps, desktop, history, templates, settings)
//   socle --headless          no window of the system (a picture, a film: socletool film)
package socle

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import host "gt:host"
import "gt:platform"
import "gt:render"
import "gt:ui"

APP_NAME  :: "socle"
APP_TITLE :: "Socle"

WINDOW_SIZE :: [2]int{1280, 800}

Page :: enum { Overview, Apps, People, Desktop, Hardware, Sound, Network, Printing, Gaming, Sharing, Power, Updates, History, Templates, All_Settings }

PAGE_NAMES := [Page]string{
	.Overview = "overview", .Apps = "apps", .People = "people", .Desktop = "desktop", .Hardware = "hardware",
	.Sound = "sound", .Network = "network", .Printing = "printing", .Gaming = "gaming", .Sharing = "sharing",
	.Power = "power", .Updates = "updates", .History = "history", .Templates = "templates", .All_Settings = "settings",
}

App :: struct {
	shared:    host.Shared,
	main:      host.Host,
	themes:    [dynamic]ui.Theme_Def,
	users:     [dynamic]ui.Theme_Def,
	choice:    ui.Theme_Choice,
	shown:     ui.Theme_Shown,
	announcer: ui.Announcer,

	page:      Page,
	version:   int,
	draft:     Settings,
	applied:   Settings,
	changes:   [dynamic]Change,
	apply:     Apply,
	history:   [dynamic]Version,

	// the pages' own state
	audience:  int,            // Apps: for everyone, or a person
	search:    ui.Line_Edit,   // Apps: the search
	option:    int,            // All settings: the option shown
	options_search: ui.Line_Edit,
}

Open_Options :: struct {
	args:     []string,
	headless: bool,
	gpu:      bool,   // headless on the graphics card (a film)
}

// socle's colours: the Midnight theme with the blue of its mark (Nix's).
THEME_SOCLE :: `[Socle]
from = Midnight
accent = #7ebae4
blue = #5277c3
light.accent = #3b6fc0
`

// The window, up to its first frame (the caller makes the frames: `frame`). nil: it cannot start, and has said why.
open :: proc(o: Open_Options) -> ^App {
	app := new(App)
	headless := o.headless
	size := WINDOW_SIZE
	app.choice = {name = "Socle", mode = .Dark, finish = .Machined, glow = 1}
	for a in o.args {
		switch {
		case a == "--headless": headless = true
		case a == "--light": app.choice.mode = .Light
		case strings.has_prefix(a, "--page="):
			for name, p in PAGE_NAMES { if name == a[len("--page="):] { app.page = p } }
		case strings.has_prefix(a, "--size="):
			v := a[len("--size="):]
			if x := strings.index_byte(v, 'x'); x > 0 {
				w, wok := strconv.parse_int(v[:x])
				h, hok := strconv.parse_int(v[x + 1:])
				if wok && hok && w > 0 && h > 0 { size = {w, h} }
			}
		}
	}
	if !host.host_open(&app.main, &app.shared, {title = APP_TITLE, size = size, headless = headless, headless_gpu = o.gpu}, build, app) {
		free(app)
		return nil
	}
	h := &app.main
	h.state.icon_font = ui.lucide_icons()
	ui.set_animations(&h.state, .On)
	ui.set_toast_position(&h.state, .Bottom_Right)
	h.after_input = 4
	h.settle = 4
	h.params = params
	app.users = ui.themes_read(THEME_SOCLE, ui.THEMES[:], ui.THEMES[0])
	append(&app.themes, ..ui.THEMES[:])
	append(&app.themes, ..app.users[:])
	app.announcer = {mode = .Window, window = h.win}

	app.version = FIRST_VERSION
	app.applied = demo_settings()
	app.history = demo_history()
	draft_set(app, app.applied)
	views_register_all(app)
	return app
}

close :: proc(app: ^App) {
	host.host_close(&app.main)
	for c in app.changes { delete(c.text) }
	delete(app.changes)
	delete(app.history)
	ui.line_edit_destroy(&app.search)
	ui.line_edit_destroy(&app.options_search)
	delete(app.themes)
	ui.themes_destroy(&app.users)
	free(app)
}

frame :: proc(app: ^App) { host.host_frame(&app.main) }

// Before each build: the theme (applied again only when what it reads changed), and what moves with the clock.
@(private = "file")
params :: proc(h: ^host.Host, p: ^ui.Build_Params) {
	app := (^App)(h.user)
	if ui.theme_show(&app.shared.theme, app.themes[:], app.choice, &app.shown, render.blend_space(&app.shared.r)) {
		platform.set_dark_title(h.win, !app.shown.light)
		h.background = ui.theme_lookup(&app.shared.theme, {}, "background")
	}
	apply_step(app)
}

main :: proc() {
	app := open({args = os.args[1:]})
	if app == nil { fmt.eprintln("socle: no window could be opened"); os.exit(1) }
	defer close(app)
	if !platform.is_offscreen(app.main.win) { platform.show_window(app.main.win) }
	for !platform.is_closed(app.main.win) {
		host.hosts_wait({&app.main})
		frame(app)
	}
}
