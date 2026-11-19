package socle_film

// socle_film: socle's presentation film, the real window driven as a person uses it (gt:film): opened headless on the
// graphics card, its frames encoded by ffmpeg (NVENC when the card has it). No window opens on the desktop.
// `socletool film [out.mp4]` builds and runs it: it links the interface, which socletool does not.

import "core:fmt"
import "core:os"
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

main :: proc() {
	out := len(os.args) > 1 ? os.args[1] : FILM_OUT
	began := time.tick_now()
	if why := shoot(out); why != "" {
		fmt.eprintfln("socle_film: %s", why)
		os.exit(1)
	}
	fmt.printfln("wrote %s in %v", out, time.tick_since(began))
}

@(private = "file")
shoot :: proc(out: string) -> string {
	t := new(Take)
	defer free(t)
	t.app = socle.open({args = {"--demo", fmt.tprintf("--size=%dx%d", WINDOW_LOGICAL.x, WINDOW_LOGICAL.y)}, headless = true, gpu = true})
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
	script(t)
	return film.finish(&t.rec)
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
	point(t, "changes_count", after = 0.6)

	// the review, now, on trial
	tap(t, "changes_review", after = 1.4)
	tap(t, "", "Now, on trial", after = 0.8)
	tap(t, "review_go", after = 0.3)
	film.pointer_show(r, true, film.center(film.box(r, "page_scroll"), {0.7, 0.6}))
	film.hold(r, socle.DEMO_PREPARE_MS / 1000 + 0.3)

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
