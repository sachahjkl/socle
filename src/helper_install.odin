package socle

// `socle helper install <folder>`: a machine installed from a folder that the installer wrote without root
// (install.odin, src/md/features/installer.md). The folder names its disk; the helper checks it, erases and formats it
// with disko, copies the folder to /mnt/etc/socle, adds the hardware's report, records the folder in git, builds the
// system into the new disk's store, and installs it.
//
// It speaks on its standard error, one line each: "@socle <Step>" when a step starts, nix's own log ("@nix {...}")
// during the builds, any other line from the programs it runs. The window and the terminal read the same lines; a
// failure's words are the last plain lines.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

INSTALL_ROOT   :: "/mnt"
INSTALL_FOLDER :: "/mnt/etc/socle"
@(private = "file") DISK_KEY :: "/run/socle/disk.key"   // nix/modules/disk.nix reads it at the format

Install_Step :: enum { Check, Disk, Folder, Hardware, Build, Install, Done }

@(private = "file")
say_step :: proc(s: Install_Step) { fmt.eprintfln("@socle %v", s) }

// Each line of a program, passed on.
@(private = "file")
pass_on :: proc(_: rawptr, text: string) { fmt.eprintln(text) }

// `command`, its standard error passed on line by line; its standard output whole.
@(private = "file")
run_said :: proc(command: []string) -> Ran {
	r := run_lines(command, "", pass_on, nil, context.temp_allocator)
	return r
}

helper_install :: proc(folder: string) -> int {
	say_step(.Check)
	target, why := install_target(folder)
	if why != "" { return helper_fail(why) }
	if why = install_disk_check(target.disk); why != "" { return helper_fail(why) }
	if mounted := run({SW + "findmnt", "-n", INSTALL_ROOT}, allocator = context.temp_allocator); mounted.ok {
		return helper_fail(fmt.tprintf("%s is in use: the install needs it free", INSTALL_ROOT))
	}
	// (the passphrase leaves the person's folder for root's: disko reads it at the format, then it is gone)
	if target.encrypt {
		key, err := os.read_entire_file_from_path(key_path(folder), context.temp_allocator)
		if err != nil || len(key) == 0 { return helper_fail("the disk's passphrase was not given") }
		_ = os.make_directory_all("/run/socle")
		if os.write_entire_file(DISK_KEY, key, {.Read_User, .Write_User}) != nil { return helper_fail("the disk's passphrase cannot be kept") }
		_ = os.remove(key_path(folder))
	}
	defer if target.encrypt { _ = os.remove(DISK_KEY) }

	say_step(.Disk)
	// (a path: flake, not git: the folder is not a repository yet. Its lock is written once, by the folder's own form
	// in git below: a path: flake's lock does not suit it)
	disko := install_build(fmt.tprintf("path:%s#nixosConfigurations.%s.config.system.build.diskoScript", folder, target.host), "", "--no-write-lock-file")
	if disko == "" { return helper_fail("the disk's script could not be built") }
	if r := run_said({disko, "--yes-wipe-all-disks"}); !r.ok { return helper_fail(fmt.tprintf("%s could not be formatted", target.disk)) }

	say_step(.Folder)
	if os.make_directory_all(join(INSTALL_ROOT, "etc")) != nil || os.copy_directory_all(INSTALL_FOLDER, folder) != nil {
		return helper_fail(fmt.tprintf("%s cannot be written", INSTALL_FOLDER))
	}

	say_step(.Hardware)
	// (a folder that brings its own hardware keeps it: a test's, or a machine prepared elsewhere)
	hardware := join(INSTALL_FOLDER, "hosts", target.host)
	if !os.exists(join(hardware, "facter.json")) && !os.exists(join(hardware, "hardware.nix")) {
		_ = os.make_directory_all(hardware)
		if r := run_said({SW + "nixos-facter", "-o", join(hardware, "facter.json")}); !r.ok { return helper_fail("the hardware could not be read") }
	}
	git :: proc(args: ..string) -> bool {
		cmd := make([dynamic]string, context.temp_allocator)
		append(&cmd, SW + "git", "-C", INSTALL_FOLDER)
		append(&cmd, ..args)
		return run_said(cmd[:]).ok
	}
	// (the group's: an administrator edits and commits without root; wheel is group 1 on every NixOS. A flake in git sees
	// only the files git knows: they are added before the lock, which then joins them in the first commit)
	if !(git("init", "-q", "--shared=group") && git("add", "-A")) { return helper_fail("git could not record the folder") }
	if r := run_said({SW + "nix", "--extra-experimental-features", "nix-command flakes", "flake", "lock", fmt.tprintf("git+file://%s", INSTALL_FOLDER)}); !r.ok {
		return helper_fail("the folder's sources could not be locked")
	}
	if !(git("add", "-A") && git("-c", "user.name=socle", "-c", "user.email=socle@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "-m", fmt.tprintf("Install from %s", target.template))) {
		return helper_fail("git could not record the folder")
	}
	_ = run({SW + "chgrp", "-R", "1", INSTALL_FOLDER}, allocator = context.temp_allocator)
	_ = run({SW + "chmod", "-R", "g+rwX", INSTALL_FOLDER}, allocator = context.temp_allocator)

	say_step(.Build)
	// (the folder's sources in the new disk's store first: the build there finds them and fetches nothing again, and
	// the installed machine can build its system with no network. A source has no signature: it comes from this
	// machine's own store)
	archive := run_said({SW + "nix", "--extra-experimental-features", "nix-command flakes", "flake", "archive", "--no-check-sigs",
		"--to", INSTALL_ROOT, fmt.tprintf("git+file://%s", INSTALL_FOLDER)})
	if !archive.ok { return helper_fail("the folder's sources could not be copied to the new disk") }
	system := install_build(fmt.tprintf("git+file://%s#nixosConfigurations.%s.config.system.build.toplevel", INSTALL_FOLDER, target.host), INSTALL_ROOT)
	if system == "" { return helper_fail("the system could not be built") }

	say_step(.Install)
	if r := run_said({SW + "nixos-install", "--root", INSTALL_ROOT, "--system", system, "--no-root-passwd", "--no-channel-copy"}); !r.ok {
		return helper_fail("the system could not be installed")
	}
	say_step(.Done)
	return 0
}

// What the folder installs: its one machine, the disk its layer names, the template.
@(private = "file")
Install_Target :: struct { host, disk, template: string, encrypt: bool }

@(private = "file")
install_target :: proc(folder: string) -> (t: Install_Target, why: string) {
	entries, err := os.read_all_directory_by_path(join(folder, "socle", "hosts"), context.temp_allocator)
	if err != nil { return t, fmt.tprintf("%s is not a folder that socle wrote", folder) }
	for e in entries {
		if !strings.has_suffix(e.name, ".json") { continue }
		if t.host != "" { return t, "the folder holds more than one machine" }
		t.host = strings.clone(e.name[:len(e.name) - len(".json")], context.temp_allocator)
	}
	if t.host == "" { return t, "the folder holds no machine" }
	machine := layer_parse(read_text(join(folder, "socle", "hosts", fmt.tprintf("%s.json", t.host)), context.temp_allocator))
	defer layer_destroy(&machine)
	t.disk = strings.clone(str(layer_get(machine, {"socle", "disk", "device"})), context.temp_allocator)
	enc, _ := layer_get(machine, {"socle", "disk", "encrypt"}).(json.Boolean)
	t.encrypt = bool(enc)
	system := layer_parse(read_text(join(folder, "socle", "system.json"), context.temp_allocator))
	defer layer_destroy(&system)
	t.template = strings.clone(layer_template(system), context.temp_allocator)
	if !strings.has_prefix(t.disk, "/dev/") { return t, "the folder names no disk" }
	return t, ""
}

// The disk can be erased: a whole disk, with nothing of it mounted or used as swap (the live image's own medium is).
// UEFI only: the base starts with systemd-boot.
@(private = "file")
install_disk_check :: proc(disk: string) -> string {
	if !os.exists("/sys/firmware/efi") { return "This machine started in legacy BIOS mode: socle installs a system that starts with UEFI." }
	r := run({SW + "lsblk", "-nr", "-o", "TYPE,MOUNTPOINTS", disk}, allocator = context.temp_allocator)
	if !r.ok { return fmt.tprintf("%s is not a disk", disk) }
	for line, i in strings.split_lines(strings.trim_space(r.stdout), context.temp_allocator) {
		fields := strings.fields(line, context.temp_allocator)
		if i == 0 && (len(fields) == 0 || fields[0] != "disk") { return fmt.tprintf("%s is not a whole disk", disk) }
		if len(fields) > 1 { return fmt.tprintf("%s is in use: %s is mounted from it", disk, fields[1]) }
	}
	return ""
}

// `target` built, its log passed on (in `store`: "" this machine's); its store path, or "" once nix's errors are said
// in plain lines (the failure's words: the last plain lines).
@(private = "file")
install_build :: proc(target, store: string, extra: ..string) -> string {
	cmd := make([dynamic]string, context.temp_allocator)
	append(&cmd, SW + "nix", "--extra-experimental-features", "nix-command flakes", "build", "--no-link", "--print-out-paths",
		"--log-format", "internal-json", "-v")
	append(&cmd, ..extra)
	// (the new disk's store, which takes from this machine's what it already has, through the daemon. As root, "auto"
	// and "local" open a local store as the new disk's is, and nix takes nothing from them: everything was built again)
	// (and all of it: NixOS's small derivations say allowSubstitutes = false, and building them needs a whole stdenv)
	if store != "" { append(&cmd, "--store", store, "--extra-substituters", "daemon?trusted=1", "--option", "always-allow-substitutes", "true") }
	append(&cmd, target)
	log: Nix_Log
	nix_log_init(&log)
	defer nix_log_destroy(&log)
	r := run_lines(cmd[:], "", proc(user: rawptr, text: string) {
		_ = nix_log_line((^Nix_Log)(user), text)
		fmt.eprintln(text)
	}, &log, context.temp_allocator)
	if !r.ok {
		if e := nix_log_errors(&log); e != "" { fmt.eprintln(e) }
		return ""
	}
	return strings.clone(strings.trim_space(r.stdout), context.temp_allocator)
}
