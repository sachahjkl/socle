package socle

import "core:strings"
import "core:testing"
import markdown "gt:markdown"
import "gt:ui"

// About metadata, version and diagnostics formatters, and the embedded changelog (window.md).
@(test)
about_info_and_whats_new_work_without_a_window :: proc(t: ^testing.T) {
	app := new(App)
	defer free(app)
	app.source = .Demo
	app.host = "house-laptop"
	app.page = .Overview
	defer markdown.doc_destroy(&app.changelog_doc)

	info := about_info(app)
	testing.expect_value(t, info.name, APP_NAME)
	testing.expect_value(t, info.version, APP_VERSION)
	testing.expect_value(t, info.tagline, "")
	testing.expect_value(t, info.licence, "MIT")
	testing.expect(t, info.on_whats_new != nil, "About has a built-in What's new action")
	testing.expect_value(t, info.website_url, APP_WEBSITE_URL)
	testing.expect_value(t, info.releases_url, APP_RELEASES_URL)

	ver := ui.about_version_text(info)
	testing.expect(t, strings.contains(ver, APP_NAME) && strings.contains(ver, APP_VERSION) && strings.contains(ver, ui.VERSION), "version text has app and toolkit versions")

	diag := ui.about_diagnostics_text(info)
	testing.expect(t, strings.contains(diag, "Target: System") && strings.contains(diag, "Host: house-laptop") && strings.contains(diag, "Licence: MIT"), "diagnostics text has target, host and licence")

	// Clicking "What's new" switches to Page.Whats_New and remembers the previous page.
	info.on_whats_new(info.user)
	testing.expect_value(t, app.page, Page.Whats_New)
	testing.expect_value(t, app.about_return, Page.Overview)

	// The embedded CHANGELOG.md starts at the newest release, drops footer link definitions, and parses in gt:markdown.
	body := changelog_body(APP_CHANGELOG)
	testing.expect(t, strings.has_prefix(body, "## ["), "changelog_body starts at the newest release")
	testing.expect(t, strings.contains(body, APP_VERSION), "changelog_body includes APP_VERSION")
	testing.expect(t, !strings.contains(body, "]: https://"), "changelog_body drops footer reference links")
	markdown.read(&app.changelog_doc, body)
	testing.expect(t, len(app.changelog_doc.blocks) > 0, "gt:markdown parses the embedded changelog")
}
