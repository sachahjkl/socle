package socle

// The apply: prepare (nix build), try (the helper activates it, a timer of the system goes back by itself), keep
// (the helper makes it the default; the folder commits the layers), or at the next start (src/md/features/apply.md).
// In the demo, preparing is a clock and the helper is this window: the stages, their order and their words are the
// real ones.

import "core:fmt"
import "core:math"
import "core:os"
import "core:strings"
import "core:sync"
import "core:time"
import lucide "gt:lucide"
import "gt:ui"

DEMO_PREPARE_MS :: 5200.0

// What the demo's build says, in nix's words.
@(private = "file", rodata)
DEMO_LOG := [?]string{
	"evaluating derivation 'path:/etc/socle#nixosConfigurations.house-laptop.config.system.build.toplevel'",
	"these 12 derivations will be built:",
	"  /nix/store/8f2k1v3m0q9x-firefox-145.0.drv",
	"  /nix/store/3h7d0s2p5l1c-krita-5.2.9.drv",
	"  /nix/store/q0w9e8r7t6y5-system-path.drv",
	"  /nix/store/z1x2c3v4b5n6-nixos-system-house-laptop-26.05.drv",
	"these 52 paths will be fetched (640.2 MiB download, 2.1 GiB unpacked):",
	"copying path '/nix/store/0a9s8d7f6g5h-gtk4-4.18.2' from 'https://cache.nixos.org'",
	"copying path '/nix/store/1q2w3e4r5t6y-mesa-25.1.4' from 'https://cache.nixos.org'",
	"copying path '/nix/store/7u8i9o0p1a2s-libreoffice-25.2.4.2' from 'https://cache.nixos.org'",
	"copying path '/nix/store/3d4f5g6h7j8k-vlc-3.0.21' from 'https://cache.nixos.org'",
	"copying path '/nix/store/9l0z1x2c3v4b-audacity-3.7.4' from 'https://cache.nixos.org'",
	"building '/nix/store/8f2k1v3m0q9x-firefox-145.0.drv'",
	"firefox> unpacking source archive /nix/store/5n6m7q8w9e0r-firefox-145.0.source.tar.xz",
	"firefox> patching sources",
	"firefox> wrapping /nix/store/2t3y4u5i6o7p-firefox-145.0/bin/firefox",
	"building '/nix/store/3h7d0s2p5l1c-krita-5.2.9.drv'",
	"krita> wrapping Qt applications in /nix/store/8a9s0d1f2g3h-krita-5.2.9",
	"building '/nix/store/q0w9e8r7t6y5-system-path.drv'",
	"system-path> created 4312 symlinks in user environment",
	"building '/nix/store/z1x2c3v4b5n6-nixos-system-house-laptop-26.05.drv'",
}
KEEP_MS         :: 60000.0

REVIEW_VIEW :: "review"
KEEP_VIEW   :: "keep"

Stage :: enum {
	Idle,
	Preparing,   // nix build
	Starting,    // the helper activates it (pkexec asks for a password)
	Trying,      // it runs on trial: keep, go back, or the timer goes back
	Finishing,   // keep, go back or at the next start: the helper and the commit
	Freeing,     // the old versions removed and the store collected (the helper's collect)
}

// The versions that Free space keeps, the newest ones: the base's setting, which nh's weekly clean keeps too
// (apply.md, "The history"), as the applied system has it.
keep_versions :: proc(app: ^App) -> int {
	if app.info != nil {
		if n := int(num(at(app.info.effective, {"base", "keepVersions"}))); n >= 1 { return n }
	}
	return 10
}

// Free space: the versions beyond the newest keep_versions removed, then the store's garbage collected.
apply_free_space :: proc(app: ^App) {
	keep := keep_versions(app)
	if apply_busy(app) || len(app.generations) <= keep { return }
	if app.source == .Demo {
		// (the demo has no store: its history only gets shorter)
		resize(&app.generations, keep)
		ui.announce(&app.announcer, .Info, "Space freed", fmt.tprintf("The newest %d versions stay.", keep))
		return
	}
	app.apply.stage = .Freeing
	if app.target == .System { helper_start(app, {"collect", fmt.tprintf("%d", keep)}); return }
	// (a home's versions are the person's: no root)
	Collect :: struct { app: ^App, keep: int, why, said: string }
	ui.task(&app.main.state, proc(d: rawptr) {
		c := (^Collect)(d)
		folder, name := profile_of(.Home)
		r := run({"nix-env", "--profile", join(folder, name), "--delete-generations", fmt.tprintf("+%d", c.keep)}, allocator = context.temp_allocator)
		if !r.ok { c.why = strings.clone(strings.trim_space(r.stderr)); return }
		g := run({"nix-collect-garbage"}, allocator = context.temp_allocator)
		if !g.ok { c.why = strings.clone(strings.trim_space(g.stderr)); return }
		for line in strings.split_lines(strings.concatenate({g.stdout, "\n", g.stderr}, context.temp_allocator), context.temp_allocator) {
			if t := strings.trim_space(line); strings.has_suffix(t, " freed") { c.said = strings.clone(t) }
		}
	}, proc(d: rawptr, _: u64) {
		c := (^Collect)(d)
		collect_done(c.app, c.why, c.said)
		delete(c.why); delete(c.said)
		free(c)
	}, new_clone(Collect{app = app, keep = keep}), proc(d: rawptr) { free(d) })
}

// Free space ended, by the helper or by the person's own nix.
@(private = "file")
collect_done :: proc(app: ^App, why, said: string) {
	app.apply.stage = .Idle
	if why != "" { ui.announce(&app.announcer, .Bad, "Space could not be freed", why, stays = true) }
	else { ui.announce(&app.announcer, .Info, "Space freed", said != "" ? said : fmt.tprintf("The newest %d versions stay.", keep_versions(app))) }
	load_start(app)
}

Apply :: struct {
	stage:      Stage,
	now:        int,     // the review's choice: 0 now (try, then keep), 1 at the next start
	started_ms: f64,     // the stage's start, on the window's clock
	at_boot:    bool,    // the applied version waits for the next start
	path:       string,  // the system built (or the version gone back to)
	summary:    string,  // the commit's message
	progress:   Progress,
	failure:    string,  // why the last apply stopped ("": it did not)
	back:       bool,    // a return to an earlier version: nothing to build or commit
	log:        Build_Log,   // the last build's lines (kept from one apply to the next: apply_reset)
}

// The lines of the last build that the window keeps (apply.md, "The build's details"), and the lines dropped at once
// when there are more: a drop is a copy of the rest, so it happens once in a while, not at each line.
LOG_KEPT :: 4000
@(private = "file") LOG_DROP :: 1000

// The last build's lines, the person's to unfold (apply.md, "The build's details").
Build_Log :: struct {
	lines:   [dynamic]string,   // owned
	ids:     [dynamic]u64,      // each line's identity in the list (its number since the build began)
	next:    u64,
	version: u64,               // moves with each change of the lines: the list's ids_version
	shown:   u64,               // the version the view followed to its end
	vl:      ui.Virtual_List,
	open:    bool,
}

build_log_clear :: proc(l: ^Build_Log) {
	for s in l.lines { delete(s) }
	clear(&l.lines)
	clear(&l.ids)
	l.next = 0
	l.version += 1
}

build_log_destroy :: proc(l: ^Build_Log) {
	build_log_clear(l)
	delete(l.lines)
	delete(l.ids)
	ui.vlist_destroy(&l.vl)
}

// Lines added at the end, the log's now; the oldest dropped past LOG_KEPT.
build_log_add :: proc(l: ^Build_Log, lines: []string) {
	if len(lines) == 0 { return }
	for s in lines {
		append(&l.lines, s)
		append(&l.ids, l.next)
		l.next += 1
	}
	if over := len(l.lines) - LOG_KEPT; over >= LOG_DROP {
		for s in l.lines[:over] { delete(s) }
		remove_range(&l.lines, 0, over)
		remove_range(&l.ids, 0, over)
	}
	l.version += 1
}

// A new apply: its state from zero, the log's lines emptied but its place on screen kept.
@(private = "file")
apply_reset :: proc(app: ^App, a: Apply) {
	delete(app.apply.failure)
	delete(app.apply.summary)
	delete(app.apply.path)
	delete(app.apply.progress.doing)
	log := app.apply.log
	app.apply = a
	app.apply.log = log
}

// What a build says of itself (nix's internal-json log).
Progress :: struct {
	builds_done, builds_expected: int,
	paths_done, paths_expected:   int,
	bytes_done, bytes_expected:   i64,
	doing:                        string,   // what it builds or downloads now
}

apply_busy :: proc(app: ^App) -> bool { return app.apply.stage != .Idle }

// How far preparing is, 0..1.
apply_fraction :: proc(app: ^App) -> f32 {
	if app.source == .Demo { return clamp(f32((ui.now_ms() - app.apply.started_ms) / DEMO_PREPARE_MS), 0, 1) }
	p := app.apply.progress
	done := f32(p.builds_done + p.paths_done)
	all := f32(p.builds_expected + p.paths_expected)
	if p.bytes_expected > 0 { return clamp(0.5 * f32(p.bytes_done) / f32(p.bytes_expected) + 0.5 * (all > 0 ? done / all : 0), 0, 1) }
	return all > 0 ? clamp(done / all, 0, 1) : 0
}

// The review accepted: the stage that prepares the new system.
apply_start :: proc(app: ^App) {
	if apply_busy(app) { return }
	apply_reset(app, {stage = .Preparing, now = app.apply.now, started_ms = ui.now_ms(), summary = summary_of(app)})
	build_log_clear(&app.apply.log)
	if app.source == .Demo { return }
	ui.task(&app.main.state, build_work, build_done, new_clone(Build{app = app, folder = app.folder, host = app.host, target = app.target}), build_lost)
}

// A home's version made the running one: its own activation, as the person (targets.md: no root, no countdown; a
// broken home takes neither the screen nor the network away, and the version before stays one click away).
@(private = "file")
Activation :: struct { app: ^App, path, why: string }

@(private = "file")
home_activate :: proc(app: ^App, path: string) {
	app.apply.stage = .Finishing
	if app.source == .Demo { apply_finished(app, false, ""); return }
	ui.task(&app.main.state, proc(d: rawptr) {
		a := (^Activation)(d)
		r := run({join(a.path, "activate")}, allocator = context.temp_allocator)
		if !r.ok {
			msg := strings.trim_space(r.stderr != "" ? r.stderr : r.stdout)
			a.why = strings.clone(msg != "" ? msg : "Home Manager's activation failed")
		}
	}, proc(d: rawptr, _: u64) {
		a := (^Activation)(d)
		apply_finished(a.app, false, a.why)
		delete(a.path); delete(a.why)
		free(a)
	}, new_clone(Activation{app = app, path = strings.clone(path)}), proc(d: rawptr) { free(d) })
}

// A return to an earlier version: the same try and keep, nothing built.
apply_go_back :: proc(app: ^App, g: Generation) {
	if apply_busy(app) || g.running { return }
	apply_reset(app, {stage = .Starting, now = 0, started_ms = ui.now_ms(), back = true, path = strings.clone(g.path), summary = fmt.aprintf("Back to version %d", g.number)})
	if app.target == .Home { home_activate(app, g.path); return }
	if app.source == .Demo { apply_try_started(app, ""); return }
	helper_start(app, {"try", g.path})
}

@(private = "file")
summary_of :: proc(app: ^App) -> string {
	switch len(app.changes) {
	case 0: return strings.clone("Apply the settings")
	case 1: return strings.clone(app.changes[0].text)
	}
	return fmt.aprintf("%s, and %d more", app.changes[0].text, len(app.changes) - 1)
}

// What moves with the clock: the demo's preparing, the countdown of a try. Called before each build.
apply_step :: proc(app: ^App) {
	switch app.apply.stage {
	case .Idle, .Starting, .Finishing, .Freeing:
	case .Preparing:
		ui.keep_animating()
		if app.source == .Demo {
			// (the demo's lines come with its clock, as a build's would)
			want := min(int(apply_fraction(app) * f32(len(DEMO_LOG))), len(DEMO_LOG))
			for int(app.apply.log.next) < want {
				line := [1]string{strings.clone(DEMO_LOG[app.apply.log.next])}
				build_log_add(&app.apply.log, line[:])
			}
			if apply_fraction(app) >= 1 { apply_built(app, "/nix/store/demo-system") }
		}
	case .Trying:
		ui.keep_animating()
		if ui.now_ms() - app.apply.started_ms >= KEEP_MS {
			// (the helper's timer has gone back already; the window follows it)
			app.apply.stage = .Idle
			ui.announce(&app.announcer, .Info, fmt.tprintf("Back to version %d", current_number(app)), "Nobody kept the new version. Your changes wait in the draft.")
			load_start(app)
		}
	}
}

// The system is built: try it now, or make it the default for the next start.
@(private = "file")
apply_built :: proc(app: ^App, path: string) {
	delete(app.apply.path)
	app.apply.path = strings.clone(path)
	app.apply.stage, app.apply.started_ms = .Starting, ui.now_ms()
	if app.target == .Home { home_activate(app, path); return }
	if app.source == .Demo {
		if app.apply.now == 1 { apply_finished(app, true, ""); return }
		apply_try_started(app, "")
		return
	}
	helper_start(app, app.apply.now == 1 ? []string{"boot", path} : []string{"try", path})
}

// The helper activated the new system: the countdown starts.
@(private = "file")
apply_try_started :: proc(app: ^App, why: string) {
	if why != "" { apply_failed(app, why); return }
	app.apply.stage, app.apply.started_ms = .Trying, ui.now_ms()
	ui.view_open(ui.state_views(&app.main.state), KEEP_VIEW, app)
}

// Keep the version on trial.
apply_keep :: proc(app: ^App) {
	app.apply.stage = .Finishing
	if app.source == .Demo { apply_finished(app, false, ""); return }
	helper_start(app, {"keep"})
}

// Go back to the running version before the try.
apply_revert :: proc(app: ^App) {
	app.apply.stage = .Finishing
	if app.source == .Demo {
		app.apply.stage = .Idle
		ui.announce(&app.announcer, .Info, fmt.tprintf("Back to version %d", current_number(app)), "Your changes wait in the draft.")
		return
	}
	app.apply.back = true   // (nothing to commit)
	helper_start(app, {"revert"})
}

@(private = "file")
apply_failed :: proc(app: ^App, why: string) {
	app.apply.stage = .Idle
	delete(app.apply.failure)
	app.apply.failure = strings.clone(why)
	ui.announce(&app.announcer, .Bad, "The new version was not applied", why, stays = true)
}

// The version is kept (or set for the next start): the folder commits the layers; the history shows it first.
@(private = "file")
apply_finished :: proc(app: ^App, at_boot: bool, why: string) {
	if why != "" { apply_failed(app, why); return }
	if app.source == .Demo {
		n := current_number(app) + 1
		for &g in app.generations { g.running = at_boot ? g.running : false; g.default_ = false }
		inject_at(&app.generations, 0, Generation{
			number = n, date = time.now(), title = strings.clone(app.apply.summary), revision = strings.clone("demo"),
			running = !at_boot, default_ = true, path = strings.clone(app.apply.path),
		})
		layer_destroy(&app.committed)
		app.committed = layer_clone(app.draft)
		for k, v in app.lock_now { app.lock_committed[k] = v }
		app.apply.stage, app.apply.at_boot = .Idle, at_boot
		changes_update(app)
		ui.announce(&app.announcer, .Good, at_boot ? fmt.tprintf("Version %d is ready", n) : fmt.tprintf("Version %d kept", n), at_boot ? "It starts at the next start of the machine." : "")
		return
	}
	app.apply.at_boot = at_boot
	if app.apply.back {
		app.apply.stage = .Idle
		load_start(app)
		return
	}
	ui.task(&app.main.state, commit_work, commit_done, new_clone(Commit{app = app, folder = app.folder, message = strings.clone(app.apply.summary)}), commit_lost)
}

current_number :: proc(app: ^App) -> int {
	for g in app.generations { if g.running { return g.number } }
	return len(app.generations) > 0 ? app.generations[0].number : 0
}

////////////////////////////////
// The build

@(private = "file")
Build :: struct {
	app:          ^App,
	folder, host: string,
	path, why:    string,
	target:       Target,
	log:          Nix_Log,   // the worker's own
	posted_ms:    f64,
	rest:         []string,  // the lines said after the last post: the end's (build_done)
}

// What the worker posts: the progress and the lines since the last post, the window's to keep.
@(private = "file")
Build_Post :: struct {
	progress: Progress,
	lines:    []string,
}

@(private = "file")
build_work :: proc(data: rawptr) {
	b := (^Build)(data)
	// (a flake in git sees only the files git knows: socle adds its own, and the person's code: README.md, "Subtleties")
	add := run({"git", "-C", b.folder, "add", "-A", "--", "socle", "custom", "flake.lock", "flake.nix"})
	delete(add.stdout); delete(add.stderr)
	nix_log_init(&b.log)
	b.log.keep_lines = true
	target := b.target == .Home ? fmt.tprintf("%s#homeConfigurations.\"%s\".activationPackage", b.folder, b.host) : fmt.tprintf("%s#nixosConfigurations.%s.config.system.build.toplevel", b.folder, b.host)
	r := run_lines({"nix", "build", "--no-link", "--print-out-paths", "--no-warn-dirty", "--log-format", "internal-json", "-v", target}, "", build_line, b)
	if r.ok {
		b.path = strings.clone(strings.trim_space(r.stdout))
	} else {
		msg := nix_log_errors(&b.log)
		b.why = strings.clone(msg != "" ? msg : "nix build failed")
	}
	delete(r.stdout); delete(r.stderr)
	b.rest = nix_log_take(&b.log)
	nix_log_destroy(&b.log)
}

@(private = "file")
build_line :: proc(user: rawptr, text: string) {
	b := (^Build)(user)
	if !nix_log_line(&b.log, text) { return }
	// (at most ten times a second: the window shows it, it need not see each line)
	now := f64(time.tick_now()._nsec) / 1e6
	if now - b.posted_ms > 100 {
		b.posted_ms = now
		p := new(Build_Post)
		p.progress = b.log.progress
		p.progress.doing = strings.clone(b.log.progress.doing)
		p.lines = nix_log_take(&b.log)
		if !ui.post(&b.app.main.state, progress_post, p) { build_post_free(p) }
	}
}

@(private = "file")
build_post_free :: proc(p: ^Build_Post) {
	delete(p.progress.doing)
	for s in p.lines { delete(s) }
	delete(p.lines)
	free(p)
}

@(private = "file")
progress_post :: proc(data: rawptr, _: u64) {
	p := (^Build_Post)(data)
	app := the_app
	if app != nil && app.apply.stage == .Preparing {
		delete(app.apply.progress.doing)
		app.apply.progress = p.progress
		build_log_add(&app.apply.log, p.lines)
		delete(p.lines)
		free(p)
		return
	}
	build_post_free(p)
}

@(private = "file")
build_done :: proc(data: rawptr, _: u64) {
	b := (^Build)(data)
	app := b.app
	if app.apply.stage == .Preparing {
		build_log_add(&app.apply.log, b.rest)
		if b.why != "" { apply_failed(app, b.why) } else { apply_built(app, b.path) }
	} else {
		for s in b.rest { delete(s) }
	}
	delete(b.rest)
	delete(b.path); delete(b.why)
	free(b)
}

@(private = "file")
build_lost :: proc(data: rawptr) {
	b := (^Build)(data)
	for s in b.rest { delete(s) }
	delete(b.rest)
	free(b)
}

////////////////////////////////
// The helper (src/md/infrastructure/helper.md): `socle helper <verb>` through pkexec

@(private = "file")
Helper_Call :: struct {
	app:  ^App,
	args: []string,
	why:  string,
	said: string,   // the helper's last line of output: collect says the space it freed
}

// The installed socle (pkexec's rule names its path), else this program.
helper_program :: proc() -> string {
	installed := "/run/current-system/sw/bin/socle"
	if t := link_target(installed); t != "" { return t }
	exe, _ := os.get_executable_path(context.temp_allocator)
	return exe
}

@(private = "file")
helper_start :: proc(app: ^App, args: []string) {
	copy := make([]string, len(args))
	for a, i in args { copy[i] = strings.clone(a) }
	ui.task(&app.main.state, helper_work, helper_done, new_clone(Helper_Call{app = app, args = copy}), helper_lost)
}

@(private = "file")
helper_work :: proc(data: rawptr) {
	h := (^Helper_Call)(data)
	command := make([dynamic]string, context.temp_allocator)
	append(&command, "pkexec", helper_program(), "helper")
	append(&command, ..h.args)
	r := run(command[:])
	switch {
	case r.ok:
		out := strings.trim_space(r.stdout)
		if i := strings.last_index_byte(out, '\n'); i >= 0 { out = out[i + 1:] }
		h.said = strings.clone(out)
	case r.code == 126 || r.code == 127:
		h.why = strings.clone("An administrator's password is needed to change the system.")
	case:
		msg := strings.trim_space(r.stderr)
		h.why = strings.clone(msg != "" ? msg : "The helper failed.")
	}
	delete(r.stdout); delete(r.stderr)
}

@(private = "file")
helper_done :: proc(data: rawptr, _: u64) {
	h := (^Helper_Call)(data)
	app := h.app
	switch h.args[0] {
	case "try":
		if app.apply.stage == .Starting { apply_try_started(app, h.why) }
	case "boot":
		apply_finished(app, true, h.why)
	case "keep":
		apply_finished(app, false, h.why)
	case "revert":
		app.apply.stage = .Idle
		if h.why != "" { ui.announce(&app.announcer, .Bad, "Going back failed", h.why, stays = true) }
		else { ui.announce(&app.announcer, .Info, "Back to the version before", "Your changes wait in the draft.") }
		load_start(app)
	case "init":
		if h.why != "" { ui.announce(&app.announcer, .Bad, "socle could not take over this machine", h.why, stays = true) }
		load_start(app)
	case "collect":
		collect_done(app, h.why, h.said)
	}
	for a in h.args { delete(a) }
	delete(h.args)
	delete(h.why)
	delete(h.said)
	free(h)
}

@(private = "file")
helper_lost :: proc(data: rawptr) { free(data) }

// The machine taken over: the helper writes /etc/socle from a template (setup.odin).
setup_start :: proc(app: ^App, ref: string) {
	helper_start(app, {"init", ref})
}

////////////////////////////////
// The commit

@(private = "file")
Commit :: struct { app: ^App, folder, message, why: string }

@(private = "file")
commit_work :: proc(data: rawptr) {
	c := (^Commit)(data)
	add := run({"git", "-C", c.folder, "add", "-A", "--", "socle", "custom", "flake.lock", "flake.nix"})
	delete(add.stdout); delete(add.stderr)
	// (socle's commits are socle's, never signed: a person's signing key is not root's, nor in every session, and a
	// commit that cannot be signed fails. The same in every commit of socle's)
	r := run({"git", "-C", c.folder, "-c", "user.name=socle", "-c", "user.email=socle@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "--allow-empty", "-m", c.message})
	if !r.ok { c.why = strings.clone(strings.trim_space(r.stderr)) }
	delete(r.stdout); delete(r.stderr)
}

@(private = "file")
commit_done :: proc(data: rawptr, _: u64) {
	c := (^Commit)(data)
	app := c.app
	app.apply.stage = .Idle
	if c.why != "" { ui.announce(&app.announcer, .Warn, "The version runs, but the folder did not record it", c.why) }
	else if app.apply.at_boot { ui.announce(&app.announcer, .Good, "The new version is ready", "It starts at the next start of the machine.") }
	else { ui.announce(&app.announcer, .Good, app.target == .Home ? "The new version runs" : "The new version is kept") }
	delete(c.message); delete(c.why)
	free(c)
	load_start(app)
}

@(private = "file")
commit_lost :: proc(data: rawptr) { free(data) }

////////////////////////////////
// The dialogs

views_register_all :: proc(app: ^App) {
	vs := ui.state_views(&app.main.state)
	ui.view_register(vs, REVIEW_VIEW, review_view, ui.View_Options{title = "Review the changes", icon = lucide.LIST_CHECKS, width_em = 34})
	ui.view_register(vs, KEEP_VIEW, keep_view, ui.View_Options{title = "Keep this version?", icon = lucide.SHIELD_CHECK, width_em = 28})
	ui.view_register(vs, EXPORT_VIEW, export_view, ui.View_Options{title = "Save as a template", icon = lucide.SAVE, width_em = 32})
}

review_open :: proc(app: ^App) {
	app.apply.now = app.target == .System && changes_restart(app) ? 1 : 0
	ui.view_open(ui.state_views(&app.main.state), REVIEW_VIEW, app)
}

@(private = "file")
review_view :: proc(v: ^ui.View, app: ^App) {
	em := ui.font_size()
	if ui.dialog_body("review_body") {
		for c, i in app.changes {
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
			if ui.row(id = fmt.tprintf("###change%d", i)) {
				if ui.tags("weak") {
					ui.next({width = ui.px(em * 6), height = ui.px(ui.dense(em * 2)), text_pad = 0})
					ui.label(fmt.tprintf("%s###change_page%d", c.page, i))
				}
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
				ui.label(fmt.tprintf("%s###change_text%d", c.text, i))
			}
			if i + 1 < len(app.changes) { ui.hline(ui.fill()) }
		}
		if app.eval_error != "" {
			ui.spacer(ui.px(em * 0.8))
			note_well("eval", lucide.ALERT_TRIANGLE, .Red, "The settings do not evaluate", app.eval_error, em)
		} else if changes_restart(app) {
			ui.spacer(ui.px(em * 0.8))
			note_well("restart", lucide.ALERT_TRIANGLE, .Yellow, "The session restarts", "A new desktop closes the open apps. Save your work first, or apply at the next start.", em)
		}
		// (a home applies at once: no start of its own, no trial)
		if app.target == .System {
			ui.spacer(ui.px(em * 0.8))
			if ui.form_row("Apply") {
				whens := [2]string{"Now, on trial", "At the next start"}
				ui.segmented("###review_when", whens[:], &app.apply.now)
			}
		}
	}
	if ui.dialog_buttons("review_buttons") {
		if ui.button("review_back", "Back").clicked { ui.view_end(v, ui.VIEW_CANCELLED) }
		if ui.button("review_go", "Prepare and apply", lucide.ARROW_RIGHT, {intent = .Primary, disabled = app.eval_error != "" || app.evaluating}).clicked {
			ui.view_end(v, 0)
			apply_start(app)
		}
	}
}

// A well with a mark, a title and a note: a warning in a dialog or a page.
note_well :: proc(id, icon: string, hue: ui.Hue, title, note: string, em: f32) {
	ui.next({width = ui.fill(), height = ui.children_sum()})
	if ui.well(fmt.tprintf("###%s_well", id), pad = ui.INNER_PAD) {
		// (a row of its own: the well lays its content in a column, which put the mark on a line alone)
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
		if ui.row(id = fmt.tprintf("###%s_line", id)) {
			// (as tall as the title's line: the mark stands beside the title, not beside the note)
			ui.next({width = ui.px(math.round(em * 1.1)), height = ui.text_size(), font = ui.lucide_icons(), fg = ui.hue(hue), text_pad = 0, text_align = .Center})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, fmt.tprintf("%s###%s_icon", icon, id))
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
			if ui.column(id = fmt.tprintf("###%s_words", id)) {
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
				ui.label(fmt.tprintf("%s###%s_title", title, id))
				if note != "" {
					if ui.tags("weak") {
						ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
						ui.label(fmt.tprintf("%s###%s_note", note, id))
					}
				}
			}
		}
	}
}

@(private = "file")
keep_view :: proc(v: ^ui.View, app: ^App) {
	em := ui.font_size()
	if app.apply.stage != .Trying && app.apply.stage != .Finishing { ui.view_end(v, ui.VIEW_CANCELLED); return }
	left := max(0, KEEP_MS - (ui.now_ms() - app.apply.started_ms))
	next := current_number(app) + (app.apply.back ? 0 : 1)
	if ui.dialog_body("keep_body") {
		ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X, cross = .Center})
		if ui.row(id = "###keep_row") {
			ui.next({width = ui.px(em * 4.2), height = ui.px(em * 3.6), font_size = em * 2.6, text_align = .Center, fg = ui.color("accent"), text_pad = 0})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, fmt.tprintf("%d###keep_seconds", int(left / 1000) + 1))
			ui.spacer(ui.px(em * 0.6))
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .Y})
			if ui.column(id = "###keep_words") {
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
				ui.label(app.apply.back ? fmt.tprintf("Version %d runs now.###keep_now", next) : fmt.tprintf("Version %d runs now.###keep_now", next))
				if ui.tags("weak") {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0, flags = {.Text_Wrap}})
					ui.label(fmt.tprintf("If nobody answers, the system goes back to version %d by itself.###keep_note", current_number(app)))
				}
			}
		}
		ui.spacer(ui.px(em * 0.7))
		ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 0.45))})
		ui.progress("###keep_left", f32(left / KEEP_MS))
	}
	if ui.dialog_buttons("keep_buttons") {
		busy := app.apply.stage == .Finishing
		if ui.button("keep_back", "Go back now", lucide.ROTATE_CCW, {disabled = busy}).clicked {
			ui.view_end(v, ui.VIEW_CANCELLED)
			apply_revert(app)
		}
		if ui.button("keep_yes", "Keep", lucide.CHECK, {intent = .Primary, busy = busy}).clicked {
			ui.view_end(v, 0)
			apply_keep(app)
		}
	}
}

_ :: sync.Mutex
