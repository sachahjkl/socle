// socletool: the project's machinery, one program, whatever the shell.
//
//   odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -- <command>
//   (build.sh and build.bat are its shortcuts for `build`)
//
// What it needs is on the path: git, odin, cargo (the toolkit's text library). GT=<folder>: another checkout of
// gui_toolkit (its root, not its src).
package socletool

import changelog "gt:changelog"
import toolbox "gt:toolbox"

REPOSITORY :: "https://github.com/sachahjkl/socle"

project :: proc() -> toolbox.Project {
	return {
		name = "socle", repository = REPOSITORY, changelog = "CHANGELOG.md",
		title = "Socle", description = "Your whole system in one window: start from a ready-made system, change any setting, go back in one step.",
		publisher = "Froment Software", copyright = "Copyright (c) 2026 sachahjkl",
	}
}

commands :: proc() -> []toolbox.Command {
	list := make([dynamic]toolbox.Command, context.temp_allocator)
	append(&list, changelog.command(project()))
	append(&list, toolbox.Command{name = "mockups", usage = "[names]  docs/mockups/*.html drawn to PNG by a headless Chromium", run = mockups_run})
	return list[:]
}

main :: proc() {
	toolbox.tool_main("socletool", commands(), toolbox.ROOT_MARK_DEFAULT)
}
