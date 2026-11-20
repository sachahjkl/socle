package socletool

// build, test, check: the toolkit's (toolbox.build_commands), the same steps on a laptop and in the CI.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import changelog "gt:changelog"
import toolbox "gt:toolbox"

// One thread: the program's tests share one interface.
@(rodata) TESTS := [?]toolbox.Test_Package{{path = "src", one_thread = true}}

build_options :: proc() -> toolbox.Build_Options {
	p := project()
	@(static) checks := [?]toolbox.Build_Check{toolkit_pinned}
	return {project = p, changelog_command = changelog.command(p), tests = TESTS[:], checks = checks[:]}
}

// The ext/gui_toolkit submodule and the flake's gui_toolkit input are one commit: the window built here is the one the
// package builds (flake.nix: the package takes the input, a github: flake comes without its submodules).
toolkit_pinned :: proc(p: toolbox.Project) -> bool {
	// (the index's commit: the one the next commit records)
	sub, code := toolbox.capture({"git", "rev-parse", ":ext/gui_toolkit"})
	if code != 0 { fmt.eprintln("socletool check: the submodule's commit cannot be read"); return false }
	text, err := os.read_entire_file_from_path("flake.lock", context.temp_allocator)
	if err != nil { fmt.eprintln("socletool check: flake.lock cannot be read"); return false }
	lock, jerr := json.parse_string(string(text), allocator = context.temp_allocator)
	node, _ := lock.(json.Object)["nodes"].(json.Object)["gui_toolkit"].(json.Object)
	rev, _ := node["locked"].(json.Object)["rev"].(json.String)
	if jerr != nil || string(rev) == "" { fmt.eprintln("socletool check: flake.lock has no gui_toolkit input"); return false }
	if strings.trim_space(sub) != string(rev) {
		fmt.eprintfln("socletool check: ext/gui_toolkit is at %s, the flake's gui_toolkit at %s: point both at the same tag", strings.trim_space(sub), rev)
		return false
	}
	return true
}
