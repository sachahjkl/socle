// socletool: the project's machinery, one program, whatever the shell.
//
//   odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -- <command>
//   (build.sh and build.bat are its shortcuts for `build`)
//
// What it needs is on the path: git, odin, cargo (the toolkit's text library). GT=<folder>: another checkout of
// gui_toolkit (its root, not its src).
package socletool

import changelog "gt:changelog"
import cli "gt:cli"
import release "gt:release"
import toolbox "gt:toolbox"

REPOSITORY :: "https://github.com/sachahjkl/socle"

project :: proc() -> toolbox.Project {
	return {
		name = "socle", repository = REPOSITORY, changelog = "CHANGELOG.md",
		version_file = "src/version.odin", version_line = "APP_VERSION :: ", program = "build/socle",
		features = {.Devtools},
		title = "Socle", description = "NixOS configuration",
		publisher = "Froment Software", copyright = "Copyright (c) 2026 sachahjkl",
	}
}

commands :: proc() -> []toolbox.Command {
	list := make([dynamic]toolbox.Command, context.temp_allocator)
	b := toolbox.build_commands(build_options())
	append(&list, b[0], b[1], b[2])
	append(&list, changelog.command(project()))
	// (notes and ship: a version is the changelog's section, its tag and the site; the program's package joins with
	// its first code)
	r := release.commands({project = project(), dist = "build/dist", check = proc() -> cli.Exit { return .Done }})
	append(&list, r[1], r[2])
	append(&list, toolbox.logo_command(logo()))
	append(&list, site_command())
	append(&list, toolbox.Command{name = "demo", usage = "src/demo/info.json: the evaluation of tests/demo that socle --demo shows", run = demo_run})
	append(&list, toolbox.Command{name = "film", usage = "[out.mp4]  the presentation film: socle's window driven headless on the graphics card (site/socle.mp4)", run = film_run})
	append(&list, toolbox.Command{name = "mockups", usage = "[names]  docs/mockups/*.html drawn to PNG by a headless Chromium", run = mockups_run})
	return list[:]
}

main :: proc() {
	toolbox.tool_main("socletool", commands(), toolbox.ROOT_MARK_DEFAULT)
}
