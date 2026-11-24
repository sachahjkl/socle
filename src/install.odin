package socle

// The installer's plan and the folder made of it (src/md/features/installer.md). The window, or `socle install` in a
// terminal, writes the folder without root: it holds the whole machine, its disk included. The helper's `install`
// takes that folder and nothing else, so what it installs is what the review showed.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

// What a person chose. Every field is checked by plan_check before the folder is written.
Plan :: struct {
	host:       string,   // the machine's name
	template:   string,   // "<input>#<name>"
	locale:     string,   // "fr_FR.UTF-8"
	keyboard:   string,   // an XKB layout: "fr"
	zone:       string,   // "Europe/Paris"
	login:      string,
	name:       string,   // the person's full name
	hash:       string,   // the password's yescrypt hash: the password itself is never written
	disk:       string,   // the whole disk, by its /dev/disk/by-id path when it has one
	encrypt:    bool,
	passphrase: string,   // the disk's: written beside the folder for the helper, never in it
	nixpkgs:    string,   // the flake's inputs ("": NIXPKGS_URL, SOCLE_URL)
	socle:      string,
	release:    string,   // the system's stateVersion ("": the running NixOS's release)
}

// What is wrong with `p`, in a person's words ("": nothing).
plan_check :: proc(p: Plan) -> string {
	switch {
	case !name_ok(p.host, 63, true):   return "The machine's name takes lowercase letters, digits and dashes."
	case !name_ok(p.login, 32, false): return "The login takes lowercase letters, digits, dashes and underscores, and starts with a letter."
	case !strings.contains(p.template, "#"): return "No template is chosen."
	case !strings.has_prefix(p.hash, "$"): return "The password is not set."
	case !strings.has_prefix(p.disk, "/dev/"): return "No disk is chosen."
	case p.encrypt && len(p.passphrase) < 8: return "The disk's passphrase needs 8 characters or more."
	case p.locale == "" || p.keyboard == "" || p.zone == "": return "The language, the keyboard and the time zone are needed."
	}
	for r in p.name { if r == '\n' || r == ':' { return "The name cannot hold a colon or a new line." } }
	return ""
}

// A host name or a login: lowercase ASCII letters, digits, dashes (and underscores in a login).
@(private = "file")
name_ok :: proc(s: string, most: int, host: bool) -> bool {
	if len(s) == 0 || len(s) > most { return false }
	for c, i in transmute([]u8)s {
		switch c {
		case 'a' ..= 'z':
		case '0' ..= '9': if i == 0 && !host { return false }
		case '-':         if i == 0 { return false }
		case '_':         if host { return false }
		case:             return false
		}
	}
	return true
}

// The folder of `p`, written in `dir` (made, empty), and the passphrase in `<dir>.key` when the disk is encrypted.
// "" or what went wrong. The machine's layer holds what belongs to this machine alone: its disk, its language, the
// password's hash; the system's layer holds what could be shared: the template and the person.
plan_write :: proc(dir: string, p: Plan) -> string {
	if why := plan_check(p); why != "" { return why }
	if os.exists(join(dir, "flake.nix")) { return fmt.tprintf("%s holds a configuration already", dir) }
	for d in ([]string{join(dir, "socle", "hosts"), join(dir, "custom")}) {
		if os.make_directory_all(d) != nil { return fmt.tprintf("%s cannot be made", d) }
	}

	system := layer_parse("")
	defer layer_destroy(&system)
	layer_set_template(&system, p.template)
	layer_set(&system, {"socle", "people", p.login, "description"}, json.String(strings.clone(p.name)))
	layer_set(&system, {"socle", "people", p.login, "admin"}, json.Boolean(true))
	// (the region in the person's layer: the Region page changes it there, region.md)
	layer_set(&system, {"i18n", "defaultLocale"}, json.String(strings.clone(p.locale)))
	layer_set(&system, {"time", "timeZone"}, json.String(strings.clone(p.zone)))
	layer_set(&system, {"services", "xserver", "xkb", "layout"}, json.String(strings.clone(p.keyboard)))

	machine := layer_parse("")
	defer layer_destroy(&machine)
	release := p.release != "" ? p.release : release_now()
	layer_set(&machine, {"system", "stateVersion"}, json.String(strings.clone(release)))
	layer_set(&machine, {"socle", "disk", "device"}, json.String(strings.clone(p.disk)))
	if p.encrypt { layer_set(&machine, {"socle", "disk", "encrypt"}, json.Boolean(true)) }
	layer_set(&machine, {"socle", "people", p.login, "hashedPassword"}, json.String(strings.clone(p.hash)))

	inputs := inputs_default(p.nixpkgs, p.socle)
	writes := [][2]string{
		{join(dir, "flake.nix"), flake_text(inputs, context.temp_allocator)},
		{join(dir, "socle", INPUTS_FILE), inputs_text(inputs, context.temp_allocator)},
		{join(dir, "socle", "system.json"), layer_text(system, context.temp_allocator)},
		{join(dir, "socle", "hosts", fmt.tprintf("%s.json", p.host)), layer_text(machine, context.temp_allocator)},
	}
	for w in writes {
		if os.write_entire_file(w[0], w[1]) != nil { return fmt.tprintf("%s cannot be written", w[0]) }
	}
	if p.encrypt {
		key := key_path(dir)
		if os.write_entire_file(key, p.passphrase, {.Read_User, .Write_User}) != nil { return fmt.tprintf("%s cannot be written", key) }
	}
	return ""
}

// Where the passphrase of the folder `dir` waits for the helper: beside the folder, never in it (the folder is
// committed).
key_path :: proc(dir: string) -> string {
	return fmt.tprintf("%s.key", strings.trim_right(dir, "/"))
}

// The running NixOS's release, "26.05" (a new system's stateVersion: the release it was installed with).
release_now :: proc() -> string {
	release := strings.trim_space(read_text("/run/current-system/nixos-version", context.temp_allocator))
	if len(release) >= 5 { return release[:5] }
	return "26.05"
}
