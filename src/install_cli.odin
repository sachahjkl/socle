package socle

// `socle install` in a terminal (the Minimal image, an install over SSH): the same plan as the window's, from flags,
// and the same helper. Without --yes it shows what it would erase and stops.
//
//   socle install --disk=<path> --template=<ref> --host=<name> --login=<login> [--name=<full name>] [--encrypt]
//                 [--locale=en_US.UTF-8] [--keyboard=us] [--zone=UTC] [--password-hash=<hash>] [--yes]
//                 [--nixpkgs=<flake url>] [--socle=<flake url>] [--release=<stateVersion>]

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

// The helper's install of the folder `dir`, through pkexec unless this is root already. Each line it says goes to
// `line`.
install_run :: proc(dir: string, line: proc(user: rawptr, text: string), user: rawptr) -> Ran {
	command := os.get_euid() == 0 ? []string{helper_program(), "helper", "install", dir} : []string{"pkexec", helper_program(), "helper", "install", dir}
	return run_lines(command, "", line, user, context.temp_allocator)
}

// What a person reads of a step.
install_step_words :: proc(s: Install_Step) -> string {
	switch s {
	case .Check:    return "Checking the disk"
	case .Disk:     return "Erasing and formatting the disk"
	case .Folder:   return "Writing the settings"
	case .Hardware: return "Reading the hardware"
	case .Build:    return "Downloading and building the system"
	case .Install:  return "Installing the system"
	case .Done:     return "Installed"
	}
	return ""
}

// A line of the helper: its step, if it is one.
install_step_of :: proc(text: string) -> (Install_Step, bool) {
	if !strings.has_prefix(text, "@socle ") { return .Check, false }
	name := text[len("@socle "):]
	for s in Install_Step { if fmt.tprint(s) == name { return s, true } }
	return .Check, false
}

install_cli :: proc(args: []string) -> int {
	p := Plan{locale = "en_US.UTF-8", keyboard = "us", zone = "UTC"}
	yes := false
	for a in args {
		value :: proc(a, flag: string) -> (string, bool) {
			if strings.has_prefix(a, flag) { return a[len(flag):], true }
			return "", false
		}
		v: string
		ok: bool
		switch {
		case a == "--yes":     yes = true
		case a == "--encrypt": p.encrypt = true
		case: if v, ok = value(a, "--disk="); ok { p.disk = v }
		      else if v, ok = value(a, "--template="); ok { p.template = v }
		      else if v, ok = value(a, "--host="); ok { p.host = v }
		      else if v, ok = value(a, "--login="); ok { p.login = v }
		      else if v, ok = value(a, "--name="); ok { p.name = v }
		      else if v, ok = value(a, "--locale="); ok { p.locale = v }
		      else if v, ok = value(a, "--keyboard="); ok { p.keyboard = v }
		      else if v, ok = value(a, "--zone="); ok { p.zone = v }
		      else if v, ok = value(a, "--password-hash="); ok { p.hash = v }
		      else if v, ok = value(a, "--nixpkgs="); ok { p.nixpkgs = v }
		      else if v, ok = value(a, "--socle="); ok { p.socle = v }
		      else if v, ok = value(a, "--release="); ok { p.release = v }
		      else { fmt.eprintfln("socle install: %s is not a flag of install", a); return 2 }
		}
	}
	if p.name == "" { p.name = p.login }
	// (the checks that need no password first: a mistake is said before any question)
	probe := p
	probe.hash, probe.passphrase = "$", "--------"
	if why := plan_check(probe); why != "" { fmt.eprintfln("socle install: %s", why); return 2 }

	about := run({"lsblk", "-dno", "MODEL,SIZE", p.disk}, allocator = context.temp_allocator)
	fmt.printfln("socle installs %s on %s as %s, for %s (%s).", p.template, p.host, p.disk, p.name, p.login)
	fmt.printfln("Everything on %s (%s) is erased.", p.disk, strings.trim_space(about.stdout))
	if !yes { fmt.println("Add --yes to install."); return 2 }

	if p.hash == "" {
		fmt.printfln("The password of %s:", p.login)
		h := run_terminal({"mkpasswd", "--method=yescrypt"})
		if !h.ok { fmt.eprintln("socle install: the password was not set"); return 1 }
		p.hash = strings.trim_space(h.stdout)
	}
	if p.encrypt {
		first := run_terminal({"systemd-ask-password", "The disk's passphrase:"})
		again := run_terminal({"systemd-ask-password", "The same passphrase again:"})
		if !first.ok || first.stdout != again.stdout { fmt.eprintln("socle install: the two passphrases differ"); return 1 }
		p.passphrase = strings.trim_right(first.stdout, "\n")
	}

	dir := fmt.tprintf("/tmp/socle-install-%d", os.get_pid())
	if why := plan_write(dir, p); why != "" { fmt.eprintfln("socle install: %s", why); return 1 }

	Said :: struct { log: Nix_Log, shown_ms: f64, last: [dynamic]string }
	said: Said
	nix_log_init(&said.log)
	defer nix_log_destroy(&said.log)
	r := install_run(dir, proc(user: rawptr, text: string) {
		s := (^Said)(user)
		if step, ok := install_step_of(text); ok { fmt.printfln("• %s", install_step_words(step)); return }
		if nix_log_line(&s.log, text) {
			// (a line every few seconds: a terminal over SSH need not get each change)
			now := f64(time.tick_now()._nsec) / 1e6
			if now - s.shown_ms > 3000 {
				s.shown_ms = now
				pr := s.log.progress
				fmt.printfln("  %d of %d built, %d of %d downloaded", pr.builds_done, pr.builds_expected, pr.paths_done, pr.paths_expected)
			}
			return
		}
		fmt.println(text)
	}, &said)
	if !r.ok {
		if e := nix_log_errors(&said.log); e != "" { fmt.eprintln(e) }
		fmt.eprintln("socle install: the install stopped")
		return 1
	}
	fmt.println("Restart the machine, without the install medium, to start the new system.")
	return 0
}
