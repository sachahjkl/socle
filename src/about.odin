package socle

// About modal and built-in What's new page (src/md/features/window.md): ui.about_modal with socle's embedded logo,
// version, diagnostics, and primary "What's new" action jumping to the embedded CHANGELOG.md rendered via gt:markdown.

import "core:fmt"
import "core:strings"
import lucide "gt:lucide"
import markdown "gt:markdown"
import png "gt:png"
import "gt:render"
import "gt:ui"

APP_TAGLINE      :: "Your whole system in one window: start from a ready-made system, change any setting, go back in one step."
APP_LICENCE      :: "MIT"
APP_COPYRIGHT    :: "© 2026 Froment Software"
APP_WEBSITE_URL  :: "https://socle.froment.software"
APP_RELEASES_URL :: "https://socle.froment.software/changelog/"
APP_REPO_URL     :: "https://github.com/sachahjkl/socle"
APP_DOCS_URL     :: "https://socle.froment.software/docs/"

APP_CHANGELOG :: #load("../CHANGELOG.md", string)
APP_LOGO_PNG  :: #load("../assets/logo_128.png")

@(private = "file", rodata)
ABOUT_LINKS := [?]ui.About_Link{
	{label = "Repository", url = APP_REPO_URL},
	{label = "Docs", url = APP_DOCS_URL, icon = lucide.BOOK_OPEN},
}

about_init :: proc(app: ^App) {
	// (embedded bytes, zero disk I/O: decoded once before the loop and uploaded to the renderer)
	rgba, w, h, ok := png.decode(APP_LOGO_PNG, context.temp_allocator)
	if !ok || w <= 0 || h <= 0 { return }
	tex := render.create_texture_rgba(&app.shared.r, w, h)
	if tex == 0 { return }
	render.update_texture_rgba(&app.shared.r, tex, 0, 0, w, h, rgba)
	app.logo = tex
}

about_destroy :: proc(app: ^App) {
	markdown.doc_destroy(&app.changelog_doc)
	if app.logo != 0 {
		render.destroy_texture(&app.shared.r, app.logo)
		app.logo = 0
	}
}

// Diagnostics already in memory: never blocks the interface thread.
about_diagnostics :: proc(app: ^App, allocator := context.temp_allocator) -> string {
	b := strings.builder_make(allocator)
	fmt.sbprintf(&b, "Target: %v", app.target)
	if app.host != "" { fmt.sbprintf(&b, "\nHost: %s", app.host) }
	if app.source == .Demo { strings.write_string(&b, "\nSource: demo") }
	if app.info != nil && app.info.release != "" { fmt.sbprintf(&b, "\nNixOS: %s", app.info.release) }
	if info := render.adapter_info(&app.shared.r); info.name != "" { fmt.sbprintf(&b, "\nRenderer: %s", info.name) }
	return strings.to_string(b)
}

about_info :: proc(app: ^App) -> ui.About_Info {
	return {
		name         = APP_NAME,
		version      = APP_VERSION,
		tagline      = APP_TAGLINE,
		licence      = APP_LICENCE,
		copyright    = APP_COPYRIGHT,
		logo         = app.logo,
		icon         = lucide.LAYERS_3,
		on_whats_new = about_open_whats_new,
		website_url  = APP_WEBSITE_URL,
		releases_url = APP_RELEASES_URL,
		links        = ABOUT_LINKS[:],
		diagnostics  = about_diagnostics(app),
		user         = app,
	}
}

@(private = "file")
about_open_whats_new :: proc(user: rawptr) {
	app := (^App)(user)
	if app.page != .Whats_New { app.about_return = app.page }
	app.page = .Whats_New
}

about_modal_build :: proc(app: ^App) {
	if !app.about_open { return }
	ui.about_modal("about", &app.about_open, about_info(app))
}

// The releases of a Keep a Changelog file: from the first `## [` heading, without the footer's reference links.
// Returns a slice of `src` so markdown.Doc keeps its pointer identity across builds.
changelog_body :: proc(src: string) -> string {
	start := strings.index(src, "## [")
	if start < 0 { return strings.trim_space(src) }
	body := src[start:]
	// (reference links sit at the bottom as "[x.y.z]: https://...")
	if at := strings.index(body, "\n["); at >= 0 {
		rest := body[at + 1:]
		if strings.contains(rest, "]: http") { body = body[:at] }
	}
	return strings.trim_right_space(body)
}

// Built-in What's new page: renders the releases of CHANGELOG.md via gt:markdown.
whats_new_page :: proc(app: ^App, em: f32, has_sidebar: bool) {
	page_head("What's new", "What changed in socle.", em)
	if !has_sidebar {
		ui.spacer(ui.px(em * 0.6))
		if ui.button("whats_new_back", "Back", lucide.ARROW_LEFT, {face = .Link}).clicked {
			app.page = app.about_return != .Whats_New ? app.about_return : .Overview
		}
	}
	ui.spacer(ui.px(em * 1.0))
	if ui.card("", id = "###whats_new_card") {
		markdown.view(&app.changelog_doc, "whats_new", changelog_body(APP_CHANGELOG), {
			prose = ui.top_style().font,
			mono  = ui.mono_font(),
			link  = proc(_: rawptr, url: string) { ui.open(url, .Url) },
		})
	}
}
