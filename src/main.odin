// socle: your whole system in one window. src/md/README.md says how it is built.
//   socle                     the window on this machine's configuration (/etc/socle)
//   socle --folder=<path>     the window on another folder that socle manages
//   socle --home              the window on this person's home (~/.config/socle), on NixOS too
//   socle --demo              the window on the demo system (tests/demo): the pictures and the film
//   socle --page=apps         a page first (overview, apps, desktop, people, history, templates, updates, settings, ...)
//   socle --headless          no window of the system (a picture, a film)
//   socle install             the installer's window (installer.odin); with --disk=..., the terminal's (install_cli.odin)
//   socle helper <verb> ...   the root part, run by pkexec (helper.odin)
package socle

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import host "gt:host"
import "gt:platform"
import "gt:render"
import "gt:ui"

APP_NAME  :: "socle"
APP_TITLE :: "Socle"

WINDOW_SIZE :: [2]int{1280, 800}

// The pages of the sidebar: socle's own, then the features' pages that the evaluation lists (generic: made from their
// options' declarations).
Page :: enum { Overview, Apps, People, Desktop, Feature, Updates, History, Templates, All_Settings }

App :: struct {
	shared:    host.Shared,
	main:      host.Host,
	themes:    [dynamic]ui.Theme_Def,
	users:     [dynamic]ui.Theme_Def,
	choice:    ui.Theme_Choice,
	shown:     ui.Theme_Shown,
	announcer: ui.Announcer,

	// where the system comes from (source.odin)
	source:      Source,
	target:      Target,   // what the folder manages: a system or a home (the worker finds it)
	folder:      string,
	folder_named: bool,    // --folder or --home: the folder is not the default of what socle runs on
	host:        string,
	load:        Load_State,
	load_error:  string,
	loading:     bool,
	info:        ^Info,
	draft:       Layer,
	committed:   Layer,
	machine:     Layer,   // this machine's layer: read only
	changes:     [dynamic]Change,
	lock_now:    map[string]i64,
	lock_committed: map[string]i64,
	generations: [dynamic]Generation,
	apply:       Apply,
	eval_due_ms: f64,
	evaluating:  bool,
	eval_error:  string,
	updating:    bool,

	// the pages' own state
	page:        Page,
	feature:     string,         // the feature page shown (its id in socle.ui.pages)
	audience:    int,            // Apps: for everyone, or a person
	search:      ui.Line_Edit,   // Apps: the search
	category:    string,         // Apps: the category shown ("": all)
	option:      string,         // All settings: the option shown
	options_search: ui.Line_Edit,
	new_person:  ui.Line_Edit,   // People: a login to add
	setup_ref:   int,            // Setup: the template chosen
	setup_sure:  bool,
	setup_templates: [dynamic]Gallery_Entry,   // Setup: socle's templates of the target, read when the folder is absent
	templates:   Template_State,                // Templates: save as a template, start from a link

	// the installer's window, in place of the system's (installer.odin): nil unless `socle install`
	installer:     ^Installer,

	// the two big lists (search.odin)
	catalogue:     Index,
	options_index: Index,
	option_values: map[string]string,   // an option's value, evaluated when it was first shown
	option_asked:  map[string]bool,
}

// The window, for the posts of the workers (one window per process).
the_app: ^App

Open_Options :: struct {
	args:     []string,
	headless: bool,
	gpu:      bool,   // headless on the graphics card (a film)
	install:  bool,   // the installer's window
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
	app.source, app.folder = .Folder, strings.clone(DEFAULT_FOLDER)
	page := ""
	for a in o.args {
		switch {
		case a == "--headless": headless = true
		case a == "--light": app.choice.mode = .Light
		case a == "--demo": app.source = .Demo
		case strings.has_prefix(a, "--folder="):
			delete(app.folder)
			abs, err := filepath.abs(a[len("--folder="):], context.allocator)
			app.folder = err == nil ? abs : strings.clone(a[len("--folder="):])
			app.folder_named = true
		case a == "--home":
			delete(app.folder)
			app.folder, app.target, app.folder_named = home_folder(), .Home, true
		case strings.has_prefix(a, "--page="): page = a[len("--page="):]
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
	the_app = app
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
	app.lock_now = make(map[string]i64)
	app.lock_committed = make(map[string]i64)
	views_register_all(app)
	if o.install {
		installer_open(app)
		return app
	}
	load_start(app)
	page_open(app, page)
	return app
}

// A page by its name on the command line.
page_open :: proc(app: ^App, name: string) {
	switch name {
	case "", "overview": app.page = .Overview
	case "apps":         app.page = .Apps
	case "people":       app.page = .People
	case "desktop":      app.page = .Desktop
	case "updates":      app.page = .Updates
	case "history":      app.page = .History
	case "templates":    app.page = .Templates
	case "settings":     app.page = .All_Settings
	case:
		app.page = .Feature
		delete(app.feature)
		app.feature = strings.clone(name)
	}
}

close :: proc(app: ^App) {
	ui.chores_stop()
	host.host_close(&app.main)
	the_app = nil
	installer_close(app)
	for c in app.changes { delete(c.text); delete(c.page) }
	delete(app.changes)
	generations_destroy(&app.generations)
	build_log_destroy(&app.apply.log)
	layer_destroy(&app.draft)
	layer_destroy(&app.committed)
	layer_destroy(&app.machine)
	gallery_destroy(&app.setup_templates)
	template_state_destroy(&app.templates)
	info_destroy(app.info)
	ui.line_edit_destroy(&app.search)
	ui.line_edit_destroy(&app.options_search)
	ui.line_edit_destroy(&app.new_person)
	index_destroy(&app.catalogue)
	index_destroy(&app.options_index)
	for k, v in app.option_values { delete(k); delete(v) }
	delete(app.option_values)
	for k in app.option_asked { delete(k) }
	delete(app.option_asked)
	delete(app.themes)
	ui.themes_destroy(&app.users)
	free(app)
}

frame :: proc(app: ^App) { host.host_frame(&app.main) }

// What a worker's answer owes the window: frames that show it.
host_settle :: proc(app: ^App) { host.host_settle(&app.main) }

// Before each build: the theme (applied again only when what it reads changed), and what moves with the clock.
@(private = "file")
params :: proc(h: ^host.Host, p: ^ui.Build_Params) {
	app := (^App)(h.user)
	if ui.theme_show(&app.shared.theme, app.themes[:], app.choice, &app.shown, render.blend_space(&app.shared.r)) {
		platform.set_dark_title(h.win, !app.shown.light)
		h.background = ui.theme_lookup(&app.shared.theme, {}, "background")
	}
}

main :: proc() {
	args := os.args[1:]
	if len(args) > 0 && args[0] == "helper" { os.exit(helper_main(args[1:])) }
	// (with a disk named, the terminal's install; without, the installer's window)
	install := len(args) > 0 && args[0] == "install"
	if install {
		args = args[1:]
		for a in args { if strings.has_prefix(a, "--disk=") { os.exit(install_cli(args)) } }
	}
	if len(args) > 0 && (args[0] == "version" || args[0] == "--version") {
		fmt.println(APP_NAME, APP_VERSION)
		return
	}
	app := open({args = args, install = install})
	if app == nil { fmt.eprintln("socle: no window could be opened"); os.exit(1) }
	defer close(app)
	if !platform.is_offscreen(app.main.win) { platform.show_window(app.main.win) }
	for !platform.is_closed(app.main.win) {
		host.hosts_wait({&app.main})
		frame(app)
	}
}
