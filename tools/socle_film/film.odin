package socle_film

// socle_film: socle's presentation film, the real window driven as a person uses it (gt:film): opened headless on the
// graphics card, its frames encoded by ffmpeg (NVENC when the card has it). No window opens on the desktop.
// `socletool film [out.mp4]` builds and runs it: it links the interface, which socletool does not.

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "gt:film"
import "gt:platform"
import "gt:render"
import "gt:ui"
import socle "../../src"

FILM_OUT :: "site/socle.mp4"
// The film's size, and the window's logical size: socle at 125 % stands on the stage (1600 x 900 on 1920 x 1080); the
// title card at 150 % fills it.
FILM_SIZE      :: [2]int{1920, 1080}
WINDOW_LOGICAL :: [2]int{1280, 720}
DPI_STAGED     :: 120
DPI_FULL       :: 144

Take :: struct {
	rec:  film.Recorder,
	app:  ^socle.App,
	card: ^Card,
}

//   socle_film [out.mp4]                    the presentation film, on the demo
//   socle_film --folder=<path> [out.mp4]    a check of a real folder: it loads, its pages, its searches; nothing applied
//   socle_film --install [out.mp4]          the installer, on the demo: each page, then the install
main :: proc() {
	out, folder, install := FILM_OUT, "", false
	for a in os.args[1:] {
		switch {
		case strings.has_prefix(a, "--folder="): folder = a[len("--folder="):]
		case a == "--install": install = true
		case: out = a
		}
	}
	began := time.tick_now()
	if why := shoot(out, folder, install); why != "" {
		fmt.eprintfln("socle_film: %s", why)
		os.exit(1)
	}
	fmt.printfln("wrote %s in %v", out, time.tick_since(began))
}

@(private = "file")
shoot :: proc(out, folder: string, install: bool) -> string {
	t := new(Take)
	defer free(t)
	source := folder != "" ? fmt.tprintf("--folder=%s", folder) : "--demo"
	t.app = socle.open({args = {source, fmt.tprintf("--size=%dx%d", WINDOW_LOGICAL.x, WINDOW_LOGICAL.y)}, headless = true, gpu = true, install = install})
	if t.app == nil { return "socle's window does not open" }
	defer socle.close(t.app)
	platform.set_offscreen_dpi(t.app.main.win, DPI_STAGED)
	for _ in 0 ..< 4 { socle.frame(t.app) }
	t.card = card_open()
	if t.card == nil { return "the title card does not open" }
	defer card_close(t.card)
	if why := film.start(&t.rec, card_app(t.card), {out = out, size = FILM_SIZE}); why != "" { return why }
	if info := render.adapter_info(&t.app.shared.r); info.software {
		fmt.eprintfln("socletool film: on the software renderer (%s): slow", info.name)
	}
	if install {
		if why := install_script(t); why != "" { _ = film.finish(&t.rec); return why }
	} else if folder != "" {
		if why := folder_script(t); why != "" { _ = film.finish(&t.rec); return why }
	} else {
		script(t)
	}
	return film.finish(&t.rec)
}

// Frames of the window, unrecorded, until `done` says so or `seconds` of real time pass: the window waits on nix,
// which takes real time; the film shows the moment after.
@(private = "file")
until :: proc(t: ^Take, done: proc(app: ^socle.App) -> bool, seconds: f64) -> bool {
	began := time.tick_now()
	for !done(t.app) {
		if time.duration_seconds(time.tick_since(began)) > seconds { return false }
		socle.frame(t.app)
		time.sleep(50 * time.Millisecond)
	}
	for _ in 0 ..< 3 { socle.frame(t.app) }
	return true
}

// A real folder: it evaluates, its pages show its values, the whole catalogue and every option are searched; a value
// changed then discarded. Nothing is built or applied.
@(private = "file")
folder_script :: proc(t: ^Take) -> string {
	r := &t.rec
	film.switch_to(r, socle_app(t))
	if !until(t, proc(app: ^socle.App) -> bool { return app.load == .Ready || app.load == .Failed || app.load == .Absent }, 300) {
		return "the folder did not load in five minutes"
	}
	if t.app.load != .Ready { return fmt.tprintf("the folder did not load: %v %s", t.app.load, t.app.load_error) }
	film.hold(r, 1.5)
	tap(t, "nav_Apps", after = 0.4)
	tap(t, "apps_field", after = 0.2)
	film.type_text(r, "inkscape", 10)
	if !until(t, proc(app: ^socle.App) -> bool { return app.catalogue.state == .Ready && app.catalogue.answered == app.catalogue.asked || app.catalogue.state == .Failed }, 600) {
		return "the catalogue was not read in ten minutes"
	}
	if t.app.catalogue.state == .Failed { return fmt.tprintf("the catalogue failed: %s", t.app.catalogue.why) }
	film.hold(r, 1.5)
	fmt.printfln("socle_film: the catalogue has %d packages; \"inkscape\" finds %d", len(t.app.catalogue.entries), len(t.app.catalogue.hits))
	fmt.printfln("socle_film: the folder is a %v, %s", t.app.target, t.app.host)
	// (a setting changed, then discarded: the desktop of a system, a shell's toggle of a home, which has no desktop)
	if t.app.target == .Home {
		tap(t, "nav_shell", after = 0.6)
		tap(t, "option_toggle1", after = 0.6)
	} else {
		tap(t, "nav_Desktop", after = 0.6)
		tap(t, "", "Plasma", after = 0.6)
	}
	// (the film's clock, past the evaluator's delay: unrecorded frames do not move it)
	film.hold(r, 1.5)
	if !until(t, proc(app: ^socle.App) -> bool { return !app.evaluating && app.eval_due_ms == 0 }, 300) { return "the draft was not evaluated" }
	film.hold(r, 1.0)
	fmt.printfln("socle_film: %d changes, evaluation: %s", len(t.app.changes), t.app.eval_error == "" ? "valid" : t.app.eval_error)
	tap(t, "changes_discard", after = 0.8)
	tap(t, "nav_All_Settings", after = 0.4)
	tap(t, "options_field", after = 0.2)
	film.type_text(r, "bluetooth powerOnBoot", 12)
	if !until(t, proc(app: ^socle.App) -> bool { return app.options_index.state == .Ready && app.options_index.answered == app.options_index.asked || app.options_index.state == .Failed }, 900) {
		return "the options were not read in fifteen minutes"
	}
	if t.app.options_index.state == .Failed { return fmt.tprintf("the options failed: %s", t.app.options_index.why) }
	fmt.printfln("socle_film: %d options; the search finds %d", len(t.app.options_index.entries), len(t.app.options_index.hits))
	film.hold(r, 1.0)
	tap(t, "option0", after = 0.4)
	until(t, proc(app: ^socle.App) -> bool { _, known := app.option_values[app.option]; return known }, 120)
	film.hold(r, 1.5)
	tap(t, "nav_History", after = 1.5)
	if t.app.target == .System {
		if why := templates_script(t); why != "" { return why }
	}
	tap(t, "nav_Overview", after = 1.5)
	return ""
}

// A template from a link (tests/template, a saved one), shown in the gallery once evaluated, then discarded; the
// applied system saved as a template (under $HOME/socle-templates: run with a HOME of its own).
@(private = "file")
templates_script :: proc(t: ^Take) -> string {
	r := &t.rec
	tap(t, "nav_Templates", after = 0.6)
	// (the page's own parts are under the gallery)
	point(t, "page_scroll", glide = 0.4, after = 0.1)
	film.wheel(r, {0, -12}, 0.6)
	film.hold(r, 0.4)
	tap(t, "template_link", after = 0.2)
	// (not in the temporary memory: each frame of the window frees it, while the link is typed)
	cwd, _ := os.get_working_directory(context.allocator)
	link := fmt.aprintf("path:%s/tests/template#my-desktop", cwd)
	defer { delete(cwd); delete(link) }
	film.type_text(r, link, 40)
	fmt.printfln("socle_film: the link typed: %q", ui.line_edit_string(&t.app.templates.link))
	tap(t, "template_link_go", after = 0.6)
	film.hold(r, 1.5)
	if !until(t, proc(app: ^socle.App) -> bool { return !app.templates.linking && !app.evaluating && app.eval_due_ms == 0 }, 600) { return "the link's template was not evaluated" }
	found := false
	for g in t.app.info.gallery { found ||= g.ref == "template-my-desktop#my-desktop" }
	fmt.printfln("socle_film: from a link: template %s, in the gallery: %v, evaluation: %s", socle.layer_template(t.app.draft), found, t.app.eval_error == "" ? "valid" : t.app.eval_error)
	if !found || t.app.eval_error != "" { return "the link's template is not in the gallery" }
	film.hold(r, 1.5)
	tap(t, "changes_discard", after = 0.8)
	if !until(t, proc(app: ^socle.App) -> bool { return !app.loading }, 300) { return "the folder was not read again" }
	fmt.printfln("socle_film: discarded: template %s, %d changes", socle.layer_template(t.app.draft), len(t.app.changes))
	tap(t, "template_save", after = 0.6)
	tap(t, "export_title", after = 0.2)
	film.type_text(r, "Our family desktop", 14)
	tap(t, "export_go", after = 0.6)
	if !until(t, proc(app: ^socle.App) -> bool { return !app.templates.saving }, 60) { return "the template was not saved" }
	dir := fmt.tprintf("%s/socle-templates/our-family-desktop", os.get_env("HOME", context.temp_allocator))
	// (a git log of HEAD: the repository has its first commit)
	committed := os.exists(fmt.tprintf("%s/.git/logs/HEAD", dir))
	fmt.printfln("socle_film: saved: %s holds a flake: %v, a commit: %v", dir, os.exists(fmt.tprintf("%s/flake.nix", dir)), committed)
	if !os.exists(fmt.tprintf("%s/flake.nix", dir)) || !committed { return "the saved template has no flake or no commit" }
	film.hold(r, 1.5)
	return ""
}

// The installer on the demo machine: a language, a disk, a person, a system, the review, the install to its end.
@(private = "file")
install_script :: proc(t: ^Take) -> string {
	r := &t.rec
	film.switch_to(r, socle_app(t))
	film.fade(r, 0.5)
	film.pointer_show(r, true, film.center(film.box(r, "install_scroll"), {0.5, 0.6}))
	film.hold(r, 1.2)
	tap(t, "wizard_next", after = 0.8)
	if t.app.installer.page != .Disk { return fmt.tprintf("Next led to %v, not to the disk", t.app.installer.page) }
	tap(t, "disk_pick0", after = 0.4)
	tap(t, "encrypt", after = 0.4)
	tap(t, "passphrase", after = 0.2)
	film.type_text(r, "correct horse", 14)
	tap(t, "passphrase2", after = 0.2)
	film.type_text(r, "correct horse", 14)
	film.hold(r, 0.6)
	tap(t, "wizard_next", after = 0.8)
	tap(t, "full_name", after = 0.2)
	film.type_text(r, "Ada Lovelace", 14)
	tap(t, "login", after = 0.2)
	film.type_text(r, "ada", 10)
	tap(t, "password", after = 0.2)
	film.type_text(r, "analytical", 14)
	tap(t, "password2", after = 0.2)
	film.type_text(r, "analytical", 14)
	film.hold(r, 0.8)
	tap(t, "wizard_next", after = 0.8)
	if t.app.installer.page != .Template { return fmt.tprintf("the person's page led to %v", t.app.installer.page) }
	tap(t, "template_pick0", after = 0.6)
	tap(t, "wizard_next", after = 1.6)
	if t.app.installer.page != .Review { return "the review did not show" }
	tap(t, "install_go", after = 0.5)
	for i := 0; i < 400 && !t.app.installer.done; i += 1 { film.hold(r, 0.1) }
	if !t.app.installer.done { return "the demo's install did not end" }
	film.hold(r, 2.5)
	return ""
}

@(private = "file")
socle_app :: proc(t: ^Take) -> film.App {
	return {win = t.app.main.win, state = &t.app.main.state, renderer = &t.app.shared.r, user = t.app,
		frame = proc(user: rawptr) { socle.frame((^socle.App)(user)) }}
}

// The pointer glides to the box named `name` (its words containing `text`) and clicks it. False, and a word on
// standard error, when the box is not there: the film goes on without that step.
@(private = "file")
tap :: proc(t: ^Take, name: string, text := "", glide := 0.6, after := 0.45) -> bool {
	b := film.box(&t.rec, name, text)
	if b == nil {
		fmt.eprintfln("socletool film: no box %q %q to click", name, text)
		return false
	}
	film.move_to(&t.rec, film.center(b), glide)
	film.hold(&t.rec, 0.1)
	film.click(&t.rec)
	film.hold(&t.rec, after)
	return true
}

// The pointer glides over the box, nothing pressed.
@(private = "file")
point :: proc(t: ^Take, name: string, text := "", glide := 0.6, after := 0.4) {
	if b := film.box(&t.rec, name, text); b != nil {
		film.move_to(&t.rec, film.center(b), glide)
		film.hold(&t.rec, after)
	}
}

// The script: the overview, apps added and one of the template's removed, the desktop changed, the review, the
// preparing, the try and the keep, the history, the templates, every option.
@(private = "file")
script :: proc(t: ^Take) {
	r := &t.rec
	card_show(t.card, "Froment Software", "socle", "Your whole system in one window")
	film.hold(r, 2.8)
	film.switch_to(r, socle_app(t))
	film.fade(r, 0.7)
	film.pointer_show(r, true, film.center(film.box(r, "page_scroll"), {0.6, 0.7}))
	film.hold(r, 1.2)
	point(t, "tile_desktop", after = 0.5)
	point(t, "status_updates", after = 0.6)

	// apps: a search, one added, one of the template's taken away
	tap(t, "nav_Apps", after = 0.6)
	tap(t, "apps_field", after = 0.2)
	film.type_text(r, "video", 9)
	film.hold(r, 0.6)
	tap(t, "app_act9", after = 0.7)    // OBS Studio
	tap(t, "app_act10", after = 0.9)   // VLC, the template's

	// the desktop: another environment, a session that opens by itself
	tap(t, "nav_Desktop", after = 0.7)
	tap(t, "", "Plasma", after = 0.8)
	tap(t, "login_toggle", after = 0.8)
	// the screen lock: its delay on the wheels, then a part typed
	tap(t, "lock_after", after = 0.7)
	point(t, "drum1", glide = 0.4, after = 0.2)
	film.wheel(r, {0, 1}, 0.25)
	film.wheel(r, {0, 1}, 0.25)
	film.wheel(r, {0, 1}, 0.25)
	film.wheel(r, {0, 5}, 0.6)
	film.hold(r, 0.9)
	film.key(r, .Escape, after = 0.5)
	// the region: a time zone found by its city
	tap(t, "nav_Region", after = 0.8)
	tap(t, "zone_field", after = 0.2)
	film.type_text(r, "tokyo", 9)
	film.hold(r, 0.8)
	tap(t, "zone_hit0", after = 1.0)
	point(t, "changes_count", after = 0.6)

	// the review, now, on trial
	tap(t, "changes_review", after = 1.4)
	tap(t, "", "Now, on trial", after = 0.8)
	tap(t, "review_go", after = 0.3)
	// the build's details, unfolded while it prepares
	tap(t, "changes_details", glide = 0.5, after = 0.2)
	film.hold(r, socle.DEMO_PREPARE_MS / 1000 - 0.5)

	// the try: the countdown runs, then keep
	film.hold(r, 2.6)
	tap(t, "keep_yes", after = 1.6)

	// the history: the new version on top
	tap(t, "nav_History", after = 1.6)
	point(t, "version_back2", after = 0.8)

	// a page made from NixOS's own options, the templates, then every option
	tap(t, "nav_printing", after = 1.2)
	tap(t, "nav_Templates", after = 1.8)
	tap(t, "nav_All_Settings", after = 0.6)
	tap(t, "options_field", after = 0.2)
	film.type_text(r, "printing", 10)
	film.hold(r, 0.5)
	tap(t, "", "services.printing.enable", after = 1.4)

	film.pointer_show(r, false)
	card_show(t.card, "", "socle", "socle.froment.software")
	film.switch_to(r, card_app(t.card))
	film.fade(r, 0.7)
	film.hold(r, 2.6)
}

_ :: ui.Box
