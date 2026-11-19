package socletool

// build, test, check: the toolkit's (toolbox.build_commands), the same steps on a laptop and in the CI.

import changelog "gt:changelog"
import toolbox "gt:toolbox"

// One thread: the program's tests share one interface.
@(rodata) TESTS := [?]toolbox.Test_Package{{path = "src", one_thread = true}}

build_options :: proc() -> toolbox.Build_Options {
	p := project()
	return {project = p, changelog_command = changelog.command(p), tests = TESTS[:]}
}
