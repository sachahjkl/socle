package socle

// `socle helper <verb>`: the only part of socle that runs as root, through pkexec and polkit's rule
// (src/md/infrastructure/helper.md). It takes fixed verbs and a store path that it checks, never a command line. The
// activation runs in a transient unit and the countdown is a timer of systemd: a session that ends, a window that
// dies or a helper that dies does not stop the return to the previous version.
//
//   socle helper try <store path>     activate it on trial; the timer goes back in KEEP_SECONDS
//   socle helper keep                 the tried version becomes the default: the profile and the boot entry
//   socle helper revert               the version before the try runs again
//   socle helper boot <store path>    the default for the next start; nothing runs now
//   socle helper init <template>      /etc/socle written from a template: socle takes this machine over
//   socle helper collect <keep>       the versions beyond the last <keep> removed, the store's garbage collected
//   socle helper install <folder>     the folder's disk erased, its system installed on it (helper_install.odin)

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:time"

KEEP_SECONDS :: 60
@(private = "file") STATE_DIR  :: "/run/socle"
@(private = "file") STATE_FILE :: "/run/socle/state.json"
@(private = "file") LOCK_FILE  :: "/run/socle/lock"
@(private = "file") SYSTEM_PROFILE :: "/nix/var/nix/profiles/system"
// (the system's programs by their full path: under pkexec, PATH is not to be trusted)
SW :: "/run/current-system/sw/bin/"
@(private = "file") REVERT_UNIT :: "socle-revert"

// Runs a verb; the exit code of the process.
helper_main :: proc(args: []string) -> int {
	if len(args) == 0 { return helper_fail("socle helper: a verb is needed (try, keep, revert, boot, init, collect)") }
	// (a verb waits for the one before to end: a try asked while the countdown goes back starts after it)
	_ = os.make_directory_all(STATE_DIR)
	if !helper_lock(LOCK_FILE) { return helper_fail(LOCK_FILE + " cannot be locked") }
	switch args[0] {
	case "try":     return len(args) == 2 ? helper_try(args[1]) : helper_fail("socle helper try <store path>")
	case "keep":    return helper_keep()
	case "revert":  return helper_revert()
	case "boot":    return len(args) == 2 ? helper_boot(args[1]) : helper_fail("socle helper boot <store path>")
	case "init":    return len(args) >= 2 ? helper_init(args[1], len(args) > 2 ? args[2] : "") : helper_fail("socle helper init <template>")
	case "collect": return len(args) == 2 ? helper_collect(args[1]) : helper_fail("socle helper collect <count>")
	case "install": return len(args) == 2 ? helper_install(args[1]) : helper_fail("socle helper install <folder>")
	}
	return helper_fail(fmt.tprintf("socle helper: no verb %s", args[0]))
}

helper_fail :: proc(why: string) -> int {
	fmt.eprintln(why)
	return 1
}

// A system that socle built: a valid path of the store, with switch-to-configuration and socle's revision. The check
// protects against a mistake, not against an administrator, who can already do anything.
@(private = "file")
system_ok :: proc(path: string) -> string {
	clean, _ := filepath.clean(path, context.temp_allocator)
	if !strings.has_prefix(clean, "/nix/store/") || strings.count(clean, "/") != 3 { return fmt.tprintf("%s is not a path of the store", path) }
	if !os.exists(join(clean, "bin", "switch-to-configuration")) { return fmt.tprintf("%s is not a system", path) }
	if !os.exists(join(clean, "socle-revision")) { return fmt.tprintf("%s was not made by socle", path) }
	r := run({SW + "nix-store", "--check-validity", clean}, allocator = context.temp_allocator)
	if !r.ok { return fmt.tprintf("%s is not valid in the store", path) }
	return ""
}

// `path`'s switch-to-configuration `action`, in a transient unit of its own: the switch may restart the display
// manager and end the session that started it.
@(private = "file")
activate :: proc(path, action: string) -> bool {
	// (a name of its own each time: a switch back, run from the countdown's service, can find the last one still loaded)
	unit := fmt.tprintf("socle-activate-%d", time.to_unix_nanoseconds(time.now()))
	r := run({SW + "systemd-run", "--unit", unit, "--collect", "--wait", "--quiet", "--service-type=oneshot",
		"--property=KillMode=process", join(path, "bin", "switch-to-configuration"), action}, allocator = context.temp_allocator)
	if !r.ok { fmt.eprint(r.stderr) }
	return r.ok
}

@(private = "file")
State :: struct { tried, previous, timer: string }

@(private = "file")
state_write :: proc(s: State) {
	_ = os.make_directory_all(STATE_DIR)
	data, _ := json.marshal(s, allocator = context.temp_allocator)
	_ = os.write_entire_file(STATE_FILE, data)
}

@(private = "file")
state_read :: proc() -> (s: State, ok: bool) {
	data, err := os.read_entire_file_from_path(STATE_FILE, context.temp_allocator)
	if err != nil { return }
	ok = json.unmarshal(data, &s, allocator = context.temp_allocator) == nil && s.tried != ""
	return
}

// The countdown stopped: its timer only. (its service is the revert that the timer runs: stopping it would end the
// helper that called this, before it goes back)
@(private = "file")
timer_stop :: proc(name: string) {
	if name == "" { return }
	_ = run({SW + "systemctl", "stop", fmt.tprintf("%s.timer", name)}, allocator = context.temp_allocator)
}

@(private = "file")
helper_try :: proc(path: string) -> int {
	if why := system_ok(path); why != "" { return helper_fail(why) }
	if _, busy := state_read(); busy { return helper_fail("a version is on trial already: keep it or go back first") }
	// (a virtual machine started from its kernel has no system profile yet: the version before is the running one)
	previous := link_target(SYSTEM_PROFILE)
	if previous == "" { previous = link_target("/run/current-system") }
	if previous == "" { return helper_fail("neither the system profile nor the running system can be read") }
	// (a try with no way back is no try)
	if !os.exists(join(previous, "bin", "switch-to-configuration")) { return helper_fail(fmt.tprintf("%s cannot be switched back to: no try without a way back", previous)) }
	// (a name of its own each time: the unit of the last countdown may still be loaded)
	timer := fmt.tprintf("%s-%d", REVERT_UNIT, time.time_to_unix(time.now()))
	state_write({tried = path, previous = previous, timer = timer})
	// (the timer first: an activation that hangs or ends the session still goes back)
	self := link_target("/proc/self/exe")
	r := run({SW + "systemd-run", "--unit", timer, "--collect", "--quiet", fmt.tprintf("--on-active=%d", KEEP_SECONDS),
		"--timer-property=AccuracySec=1s", self, "helper", "revert"}, allocator = context.temp_allocator)
	if !r.ok { os.remove(STATE_FILE); return helper_fail(fmt.tprintf("the countdown could not start: %s", r.stderr)) }
	if !activate(path, "test") {
		helper_revert()
		return helper_fail("the new version did not start; the previous one runs again")
	}
	return 0
}

@(private = "file")
helper_keep :: proc() -> int {
	s, ok := state_read()
	if !ok { return helper_fail("no version is on trial") }
	timer_stop(s.timer)
	r := run({SW + "nix-env", "--profile", SYSTEM_PROFILE, "--set", s.tried}, allocator = context.temp_allocator)
	if !r.ok { return helper_fail(r.stderr) }
	if !activate(s.tried, "boot") { return helper_fail("the boot entry could not be written") }
	os.remove(STATE_FILE)
	return 0
}

@(private = "file")
helper_revert :: proc() -> int {
	s, ok := state_read()
	if !ok { return 0 }   // (kept already, or gone back by the timer)
	timer_stop(s.timer)
	os.remove(STATE_FILE)
	if !activate(s.previous, "test") { return helper_fail("the previous version did not start again") }
	return 0
}

@(private = "file")
helper_boot :: proc(path: string) -> int {
	if why := system_ok(path); why != "" { return helper_fail(why) }
	r := run({SW + "nix-env", "--profile", SYSTEM_PROFILE, "--set", path}, allocator = context.temp_allocator)
	if !r.ok { return helper_fail(r.stderr) }
	if !activate(path, "boot") { return helper_fail("the boot entry could not be written") }
	return 0
}

@(private = "file")
helper_collect :: proc(count: string) -> int {
	// (a number of versions, at least one: nix-env reads "+<n>", and 0 would remove the running one's entry)
	n, nok := strconv.parse_int(count, 10)
	if !nok || n < 1 { return helper_fail(fmt.tprintf("%s is not a count of versions", count)) }
	r := run({SW + "nix-env", "--profile", SYSTEM_PROFILE, "--delete-generations", fmt.tprintf("+%s", count)}, allocator = context.temp_allocator)
	if !r.ok { return helper_fail(r.stderr) }
	g := run({SW + "nix-collect-garbage"}, allocator = context.temp_allocator)
	if !g.ok { return helper_fail(g.stderr) }
	// (nix's summary, "<n> store paths deleted, <size> freed": the window shows it)
	for line in strings.split_lines(strings.concatenate({g.stdout, "\n", g.stderr}, context.temp_allocator), context.temp_allocator) {
		// (a path named freedesktop is not the summary)
		if t := strings.trim_space(line); strings.has_suffix(t, " freed") { fmt.println(t) }
	}
	return 0
}

// The flake of a folder that socle manages: its inputs and one call to socle's library (configuration.md).
FLAKE_TEXT :: `{
  description = "This machine's system, managed by socle: socle/*.json are its settings, custom/*.nix its code.";
  inputs = {
    nixpkgs.url = "%s";
    socle = {
      url = "%s";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs: inputs.socle.lib.configuration {
    inherit inputs;
    root = ./.;
  };
}
`

SOCLE_URL   :: "git+https://github.com/sachahjkl/socle?submodules=1"
NIXPKGS_URL :: "https://flakehub.com/f/NixOS/nixpkgs/0.2605"

// /etc/socle from a template: the flake, the system's layer, this machine's layer (its name, its people, its
// release), its hardware (nixos-generate-config), a git history. Refused when the folder holds a configuration.
@(private = "file")
helper_init :: proc(template, source: string) -> int {
	folder := DEFAULT_FOLDER
	if os.exists(join(folder, "flake.nix")) { return helper_fail("/etc/socle holds a configuration already") }
	host := strings.trim_space(read_text("/etc/hostname", context.temp_allocator))
	if host == "" { host = "nixos" }
	hw := join(folder, "hosts", host)
	for d in ([]string{join(folder, "socle", "hosts"), hw, join(folder, "custom")}) {
		if os.make_directory_all(d) != nil { return helper_fail(fmt.tprintf("%s cannot be made", d)) }
	}
	_ = os.write_entire_file(join(folder, "flake.nix"), fmt.tprintf(FLAKE_TEXT, NIXPKGS_URL, source != "" ? source : SOCLE_URL))
	_ = os.write_entire_file(join(folder, "socle", "system.json"), fmt.tprintf("{{\n  \"socle\": 1,\n  \"template\": %q,\n  \"values\": {{\n    \"socle\": {{\"people\": {{%s}}}}\n  }}\n}}\n", template, people_json()))
	machine := layer_parse("")
	defer layer_destroy(&machine)
	layer_set(&machine, {"system", "stateVersion"}, json.String(strings.clone(release_now())))
	if why := boot_loader_found(&machine); why != "" { return helper_fail(why) }
	_ = os.write_entire_file(join(folder, "socle", "hosts", fmt.tprintf("%s.json", host)), layer_text(machine, context.temp_allocator))
	hardware := run({SW + "nixos-generate-config", "--show-hardware-config"}, allocator = context.temp_allocator)
	if !hardware.ok { return helper_fail(fmt.tprintf("the hardware cannot be read: %s", hardware.stderr)) }
	_ = os.write_entire_file(join(hw, "hardware.nix"), hardware.stdout)
	git :: proc(folder: string, args: ..string) -> bool {
		cmd := make([dynamic]string, context.temp_allocator)
		append(&cmd, SW + "git", "-C", folder)
		append(&cmd, ..args)
		return run(cmd[:], allocator = context.temp_allocator).ok
	}
	// (the group's: an administrator edits and commits without root)
	ok := git(folder, "init", "-q", "--shared=group") && git(folder, "add", "-A") &&
		git(folder, "-c", "user.name=socle", "-c", "user.email=socle@localhost", "commit", "-q", "-m", fmt.tprintf("Start from %s", template))
	if !ok { return helper_fail("git could not record the folder") }
	_ = run({SW + "chgrp", "-R", "wheel", folder}, allocator = context.temp_allocator)
	_ = run({SW + "chmod", "-R", "g+rwX", folder}, allocator = context.temp_allocator)
	return 0
}

// The boot loader this machine starts with, in its layer: socle's base starts with systemd-boot, and a machine that
// starts with GRUB must keep it, on its own disk. Found from what is on the boot partition, never from the Nix that a
// person wrote. "" or why it cannot be known.
@(private = "file")
boot_loader_found :: proc(machine: ^Layer) -> string {
	uefi := os.exists("/sys/firmware/efi")
	// (the EFI partition where it is mounted: /boot, or /boot/efi on older machines)
	esp := ""
	for at in ([]string{"/boot", "/boot/efi", "/efi"}) {
		r := run({SW + "findmnt", "-no", "FSTYPE", at}, allocator = context.temp_allocator)
		if r.ok && strings.trim_space(r.stdout) == "vfat" { esp = at; break }
	}
	if esp != "" && esp != "/boot" {
		layer_set(machine, {"boot", "loader", "efi", "efiSysMountPoint"}, json.String(strings.clone(esp)))
	}
	switch {
	case os.exists("/boot/loader/loader.conf") || (esp != "" && os.exists(join(esp, "loader", "loader.conf"))):
		return ""   // (systemd-boot: the base's)
	// (NixOS keeps GRUB's configuration on /boot, with UEFI or without)
	case os.exists("/boot/grub/grub.cfg"):
		layer_set(machine, {"boot", "loader", "systemd-boot", "enable"}, json.Boolean(false))
		layer_set(machine, {"boot", "loader", "grub", "enable"}, json.Boolean(true))
		if uefi {
			layer_set(machine, {"boot", "loader", "grub", "efiSupport"}, json.Boolean(true))
			layer_set(machine, {"boot", "loader", "grub", "device"}, json.String(strings.clone("nodev")))
			return ""
		}
		// (BIOS: GRUB goes on the disk that holds /boot, else /)
		source := run({SW + "findmnt", "-no", "SOURCE", "/boot"}, allocator = context.temp_allocator)
		if !source.ok { source = run({SW + "findmnt", "-no", "SOURCE", "/"}, allocator = context.temp_allocator) }
		disk := run({SW + "lsblk", "-no", "PKNAME", strings.trim_space(source.stdout)}, allocator = context.temp_allocator)
		name := strings.trim_space(disk.stdout)
		if !disk.ok || name == "" { return "the disk that GRUB starts from cannot be found" }
		layer_set(machine, {"boot", "loader", "grub", "device"}, json.String(fmt.aprintf("/dev/%s", name)))
		return ""
	}
	return "socle does not know this machine's boot loader: neither systemd-boot nor GRUB is on its boot partition"
}

// The people of this machine (the accounts of /etc/passwd from 1000 up), as the system layer's: an administrator is in
// the group wheel. Their passwords stay in /etc/shadow (the accounts are mutable).
@(private = "file")
people_json :: proc() -> string {
	wheel := ""
	for line in strings.split_lines(read_text("/etc/group", context.temp_allocator), context.temp_allocator) {
		if strings.has_prefix(line, "wheel:") { wheel = line[strings.last_index_byte(line, ':') + 1:] }
	}
	b := strings.builder_make(context.temp_allocator)
	first := true
	for line in strings.split_lines(read_text("/etc/passwd", context.temp_allocator), context.temp_allocator) {
		f := strings.split(line, ":", context.temp_allocator)
		if len(f) < 7 { continue }
		uid := 0
		for c in f[2] { uid = uid * 10 + int(c - '0') }
		if uid < 1000 || uid >= 30000 { continue }
		admin := false
		for w in strings.split(wheel, ",", context.temp_allocator) { admin ||= w == f[0] }
		if !first { strings.write_string(&b, ", ") }
		first = false
		fmt.sbprintf(&b, "%q: {{\"description\": %q, \"admin\": %v}}", f[0], f[4], admin)
	}
	return strings.to_string(b)
}
