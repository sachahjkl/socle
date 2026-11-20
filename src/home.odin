package socle

// A home that socle starts (src/md/data/targets.md): the person's own folder, ~/.config/socle, written as the
// installer writes a machine's (install.odin): the flake, the person's layer with its template, and this home's own
// layer (who, where, which release), named <person>@<host> as Home Manager names a home. No root: the person owns it.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "gt:ui"

// The folder of a home, written in `dir`: "" or what went wrong.
home_write :: proc(dir, template, user, home_dir, host, socle_url: string) -> string {
	if os.exists(join(dir, "flake.nix")) { return fmt.tprintf("%s holds a configuration already", dir) }
	for d in ([]string{join(dir, "socle", "homes"), join(dir, "custom")}) {
		if os.make_directory_all(d) != nil { return fmt.tprintf("%s cannot be made", d) }
	}
	person := layer_parse("")
	defer layer_destroy(&person)
	layer_set_template(&person, template)
	own := layer_parse("")
	defer layer_destroy(&own)
	layer_set(&own, {"home", "username"}, json.String(strings.clone(user)))
	layer_set(&own, {"home", "homeDirectory"}, json.String(strings.clone(home_dir)))
	// (Home Manager's release this home starts with: socle's own, which its flake follows)
	layer_set(&own, {"home", "stateVersion"}, json.String(strings.clone(HOME_RELEASE)))
	name := host != "" ? fmt.tprintf("%s@%s", user, host) : user
	writes := [][2]string{
		{join(dir, "flake.nix"), flake_text(inputs_default("", socle_url), context.temp_allocator)},
		{join(dir, "socle", INPUTS_FILE), inputs_text(inputs_default("", socle_url), context.temp_allocator)},
		{join(dir, "socle", "system.json"), layer_text(person, context.temp_allocator)},
		{join(dir, "socle", "homes", fmt.tprintf("%s.json", name)), layer_text(own, context.temp_allocator)},
	}
	for w in writes {
		if os.write_entire_file(w[0], w[1]) != nil { return fmt.tprintf("%s cannot be written", w[0]) }
	}
	git :: proc(dir: string, args: ..string) -> bool {
		cmd := make([dynamic]string, context.temp_allocator)
		append(&cmd, "git", "-C", dir)
		append(&cmd, ..args)
		return run(cmd[:], allocator = context.temp_allocator).ok
	}
	if !(git(dir, "init", "-q") && git(dir, "add", "-A") &&
		git(dir, "-c", "user.name=socle", "-c", "user.email=socle@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "-m", fmt.tprintf("Start from %s", template))) {
		return "git could not record the folder"
	}
	return ""
}

// Home Manager's release of socle's flake (its input follows the same Nixpkgs).
HOME_RELEASE :: "26.05"

@(private = "file")
Home_Start :: struct { app: ^App, folder, template, why: string }

// The person's home started from `ref`: its folder written, then read as any folder.
home_setup_start :: proc(app: ^App, ref: string) {
	if app.loading { return }
	app.loading = true
	ui.task(&app.main.state, proc(d: rawptr) {
		h := (^Home_Start)(d)
		home_dir := os.get_env("HOME", context.temp_allocator)
		user := os.get_env("USER", context.temp_allocator)
		if user == "" || home_dir == "" { h.why = strings.clone("HOME and USER are not set"); return }
		if why := home_write(h.folder, h.template, user, home_dir, machine_hostname(), ""); why != "" { h.why = strings.clone(why) }
	}, proc(d: rawptr, _: u64) {
		h := (^Home_Start)(d)
		app := h.app
		app.loading = false
		if h.why != "" { ui.announce(&app.announcer, .Bad, "Your home could not be started", h.why, stays = true) }
		else { load_start(app) }
		delete(h.folder); delete(h.template); delete(h.why)
		free(h)
	}, new_clone(Home_Start{app = app, folder = strings.clone(app.folder), template = strings.clone(ref)}), proc(d: rawptr) { free(d) })
}
