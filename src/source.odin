package socle

// Where the window's system comes from, and the work that reads and writes it. Every read, write, git and nix call is
// a task on the chores (ui.task); its result comes back to the interface's thread at a next build.
//
// - Demo: a kept evaluation of tests/demo (demo/info.json) and its layer; the apply runs on a clock.
// - Folder: a folder that socle manages (/etc/socle, or --folder): its layers, its git history, `nix eval` of its
//   socleInfo, the system's versions in /nix/var/nix/profiles.

import "core:crypto/sha2"
import "core:encoding/hex"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import "gt:ui"

DEMO_INFO   :: #load("demo/info.json", string)
DEMO_LAYER  :: #load("demo/system.json", string)
DEMO_MACHINE :: #load("demo/host.json", string)
DEMO_HOST   :: "house-laptop"
DEFAULT_FOLDER :: "/etc/socle"
PROFILES    :: "/nix/var/nix/profiles"

Source :: enum { Demo, Folder }

// What socle manages (src/md/data/targets.md): a whole NixOS machine, or one person's home through Home Manager.
Target :: enum { System, Home }

// Where a target keeps its own layer, beside socle/system.json.
target_dir :: proc(t: Target) -> string { return t == .Home ? "homes" : "hosts" }

// A home's folder: the person's own.
home_folder :: proc() -> string {
	return strings.clone(join(os.get_env("HOME", context.temp_allocator), ".config", "socle"))
}

Load_State :: enum {
	Loading,   // the first read is under way
	Ready,
	Absent,    // the folder holds no configuration of socle's: the setup page
	Failed,    // read, but the evaluation failed (load_error says why)
}

// A version of the system: a generation of the system profile, joined to the commit that made it by the layers' hash.
Generation :: struct {
	number:   int,
	path:     string,
	date:     time.Time,
	revision: string,
	title:    string,   // the commit's subject; "" when no commit of the folder made it
	running:  bool,
	default_: bool,     // the one the next start runs
}

////////////////////////////////
// Load

@(private = "file")
Loaded :: struct {
	app:            ^App,
	state:          Load_State,
	why:            string,
	folder:         string,   // the folder read: the one named, else the default of what socle runs on
	target:         Target,
	pick:           bool,     // no folder named: the target comes from what socle runs on
	host:           string,
	info:           ^Info,
	draft, committed: string,
	machine:        string,   // the machine's layer (socle/hosts/<host>.json): read only, its values shown as "this machine"
	lock_now, lock_committed: map[string]i64,
	generations:    [dynamic]Generation,
}

// Reads the folder again (the whole of it: after an apply, an update, a start).
load_start :: proc(app: ^App) {
	if app.source == .Demo { demo_load(app); return }
	app.loading = true
	l := Loaded{app = app, host = strings.clone(app.host), folder = strings.clone(app.folder), target = app.target, pick = !app.folder_named}
	ui.task(&app.main.state, load_work, load_done, new_clone(l), load_lost)
}

@(private = "file")
load_work :: proc(data: rawptr) {
	l := (^Loaded)(data)
	// (no folder named: a NixOS is managed whole, any other system has a home: targets.md, "The start")
	if l.pick && l.target == .System && !os.exists("/etc/NIXOS") {
		l.target = .Home
		delete(l.folder)
		l.folder = home_folder()
	}
	folder := l.folder
	if !os.exists(join(folder, "flake.nix")) || !os.exists(join(folder, "socle")) {
		l.state = .Absent
		return
	}
	// (a folder holds one target: its layers say which)
	if os.exists(join(folder, "socle", "homes")) && !os.exists(join(folder, "socle", "hosts")) { l.target = .Home }
	if os.exists(join(folder, "socle", "hosts")) { l.target = .System }
	if l.host == "" { l.host = pick_host(folder, l.target) }
	if l.host == "" { l.state, l.why = .Failed, fmt.aprintf("socle/%s holds nothing", target_dir(l.target)); return }
	l.draft = read_text(join(folder, "socle", "system.json"))
	l.committed = git_show(folder, "HEAD:socle/system.json")
	l.machine = read_text(join(folder, "socle", target_dir(l.target), fmt.tprintf("%s.json", l.host)))
	l.lock_now = lock_dates(read_text(join(folder, "flake.lock")))
	l.lock_committed = lock_dates(git_show(folder, "HEAD:flake.lock"))
	text, why := evaluate(folder, l.host)
	if why != "" {
		l.state, l.why = .Failed, why
	} else {
		info, perr := info_parse(text)
		if info == nil { l.state, l.why = .Failed, strings.clone(perr) } else { l.info, l.state = info, .Ready }
	}
	l.generations = generations_read(folder, l.host, l.target)
}

@(private = "file")
load_done :: proc(data: rawptr, _: u64) {
	l := (^Loaded)(data)
	app := l.app
	app.loading = false
	app.load, app.load_error = l.state, l.why
	app.target = l.target
	delete(app.folder)
	app.folder = l.folder
	// (the start page's templates, of the target found: read once, here, not in a frame)
	if l.state == .Absent {
		gallery_destroy(&app.setup_templates)
		app.setup_templates = templates_of(app.target)
	}
	if l.host != "" { delete(app.host); app.host = l.host }
	if l.info != nil {
		info_destroy(app.info)
		app.info = l.info
	}
	if l.state == .Ready || l.state == .Failed {
		layer_destroy(&app.draft)
		layer_destroy(&app.committed)
		app.draft = layer_parse(l.draft)
		app.committed = layer_parse(l.committed)
		layer_destroy(&app.machine)
		app.machine = layer_parse(l.machine)
		delete(app.lock_now); delete(app.lock_committed)
		app.lock_now, app.lock_committed = l.lock_now, l.lock_committed
		generations_destroy(&app.generations)
		app.generations = l.generations
		changes_update(app)
	}
	delete(l.draft)
	delete(l.committed)
	delete(l.machine)
	free(l)
	host_settle(app)
}

@(private = "file")
load_lost :: proc(data: rawptr) { free(data) }

// This machine's name in the folder when the folder has it, else the first: a host by its name, a home as
// <person>@<host> (Home Manager's own way), else as <person>.
@(private = "file")
pick_host :: proc(folder: string, target: Target) -> string {
	entries, err := os.read_all_directory_by_path(join(folder, "socle", target_dir(target)), context.temp_allocator)
	if err != nil { return "" }
	names := make([dynamic]string, context.temp_allocator)
	for e in entries { if strings.has_suffix(e.name, ".json") { append(&names, strings.trim_suffix(e.name, ".json")) } }
	slice.sort(names[:])
	host := machine_hostname()
	user := os.get_env("USER", context.temp_allocator)
	wanted := target == .Home ? []string{fmt.tprintf("%s@%s", user, host), user} : []string{host}
	for w in wanted { for n in names { if n == w { return strings.clone(n) } } }
	return len(names) > 0 ? strings.clone(names[0]) : ""
}

// This machine's host name (/etc/hostname, else the kernel's).
machine_hostname :: proc() -> string {
	name := strings.trim_space(read_text("/etc/hostname", context.temp_allocator))
	if name == "" { name = strings.trim_space(read_text("/proc/sys/kernel/hostname", context.temp_allocator)) }
	return name
}

read_text :: proc(path: string, allocator := context.allocator) -> string {
	data, err := os.read_entire_file_from_path(path, allocator)
	return err == nil ? string(data) : ""
}

git_show :: proc(folder, what: string) -> string {
	r := run({"git", "-C", folder, "show", what})
	delete(r.stderr)
	if !r.ok { delete(r.stdout); return "" }
	return r.stdout
}

// The flake's evaluation for the window (lib.nix, socleInfo): its JSON, or why it failed (nix's own words).
evaluate :: proc(folder, host: string) -> (text: string, why: string) {
	// (the name quoted: a home's holds an @)
	r := run({"nix", "eval", "--json", "--no-warn-dirty", fmt.tprintf("%s#socleInfo.\"%s\"", folder, host)})
	if !r.ok {
		delete(r.stdout)
		return "", nix_error(r.stderr)
	}
	delete(r.stderr)
	return r.stdout, ""
}

// What a failed nix command says, from its first "error:" on (its trace is long and seldom what a person needs).
nix_error :: proc(stderr: string) -> string {
	s := stderr
	if at := strings.last_index(s, "error:"); at >= 0 { s = s[at:] } else { s = "" }
	out := strings.clone(strings.trim_space(s))
	delete(stderr)
	return out == "" ? strings.clone("nix failed") : out
}

// The lastModified of each input of a flake.lock (the root's inputs, by their names).
lock_dates :: proc(text: string) -> map[string]i64 {
	out := make(map[string]i64)
	if text == "" { return out }
	v, err := json.parse_string(text, parse_integers = true, allocator = context.temp_allocator)
	if err != nil { return out }
	nodes, _ := at(v, {"nodes"}).(json.Object)
	root_inputs, _ := at(v, {"nodes", "root", "inputs"}).(json.Object)
	for name, ref in root_inputs {
		key, is := ref.(json.String)
		if !is { continue }   // (a follows: no lock of its own)
		out[strings.clone(name)] = i64(num(at(nodes[string(key)], {"locked", "lastModified"})))
	}
	return out
}

date_words :: proc(t: i64) -> string {
	if t == 0 { return "an unknown date" }
	y, m, d := time.date(time.unix(t, 0))
	MONTHS := [?]string{"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	return fmt.tprintf("%d %s %d", d, MONTHS[int(m) - 1], y)
}

////////////////////////////////
// The versions of the system

// The generations of the system profile, newest first, each joined to its commit (the layers' hash of each commit of
// the folder, until every generation is named).
generations_read :: proc(folder, host: string, target: Target) -> [dynamic]Generation {
	out := make([dynamic]Generation)
	profiles, name := profile_of(target)
	entries, err := os.read_all_directory_by_path(profiles, context.temp_allocator)
	if err != nil { return out }
	// (a home has no start of its own: the version that runs is its profile's)
	default_ := link_target(join(profiles, name))
	running := target == .Home ? default_ : link_target("/run/current-system")
	prefix := fmt.tprintf("%s-", name)
	for e in entries {
		if !strings.has_prefix(e.name, prefix) || !strings.has_suffix(e.name, "-link") { continue }
		n, ok := strconv.parse_int(e.name[len(prefix):len(e.name) - len("-link")])
		if !ok { continue }
		link := join(profiles, e.name)
		path := link_target(link)
		info, _ := os.lstat(link, context.temp_allocator)
		g := Generation{number = n, path = strings.clone(path), date = info.modification_time}
		g.revision = strings.trim_space(read_text(join(path, "socle-revision")))
		g.running = path != "" && path == running
		g.default_ = path != "" && path == default_
		append(&out, g)
	}
	slice.sort_by(out[:], proc(a, b: Generation) -> bool { return a.number > b.number })
	// the commits: their layers' hash, until each generation of socle's has its title
	wanted := 0
	for g in out { if g.revision != "" { wanted += 1 } }
	if wanted == 0 { return out }
	r := run({"git", "-C", folder, "log", "-n", "60", "--format=%H%x1f%s"}, allocator = context.temp_allocator)
	if !r.ok { return out }
	for line in strings.split_lines(r.stdout, context.temp_allocator) {
		if wanted == 0 { break }
		parts := strings.split(line, "\x1f", context.temp_allocator)
		if len(parts) != 2 { continue }
		system := git_show(folder, fmt.tprintf("%s:socle/system.json", parts[0]))
		host_text := git_show(folder, fmt.tprintf("%s:socle/%s/%s.json", parts[0], target_dir(target), host))
		h := layers_hash(system, host_text)
		delete(system); delete(host_text)
		for &g in out {
			if g.revision == h && g.title == "" {
				g.title = strings.clone(parts[1])
				wanted -= 1
			}
		}
	}
	return out
}

// Where a target's versions are: the folder of its profile and the profile's name. A home's is Home Manager's, in the
// person's state folder, or in /nix/var/nix/profiles/per-user when Nix keeps it there.
profile_of :: proc(target: Target) -> (folder, name: string) {
	if target == .System { return PROFILES, "system" }
	state := os.get_env("XDG_STATE_HOME", context.temp_allocator)
	if state == "" { state = join(os.get_env("HOME", context.temp_allocator), ".local", "state") }
	folder = join(state, "nix", "profiles")
	if !os.exists(join(folder, "home-manager")) {
		folder = join(PROFILES, "per-user", os.get_env("USER", context.temp_allocator))
	}
	return folder, "home-manager"
}

generations_destroy :: proc(gs: ^[dynamic]Generation) {
	for g in gs { delete(g.path); delete(g.revision); delete(g.title) }
	delete(gs^)
	gs^ = nil
}

// The layers' hash, as the library computes it (lib.nix: sha256 of the system layer's text then the host's).
layers_hash :: proc(system, host: string) -> string {
	ctx: sha2.Context_256
	sha2.init_256(&ctx)
	sha2.update(&ctx, transmute([]u8)system)
	sha2.update(&ctx, transmute([]u8)host)
	sum: [sha2.DIGEST_SIZE_256]u8
	sha2.final(&ctx, sum[:])
	return string(hex.encode(sum[:], context.temp_allocator))
}

link_target :: proc(path: string) -> string {
	// (a profile's link is relative: system-215-link; /run/current-system is absolute; both resolve to the store)
	p := path
	for _ in 0 ..< 8 {
		t, err := os.read_link(p, context.temp_allocator)
		if err != nil { break }
		p = filepath.is_abs(t) ? t : join(filepath.dir(p), t)
	}
	return p == path ? "" : p
}

////////////////////////////////
// The draft, saved and evaluated

// The draft changed: its file is written at once (no Save button), the changes made again, and an evaluation asked
// for a moment after the last change.
draft_changed :: proc(app: ^App) {
	changes_update(app)
	if app.source != .Folder { return }
	text := layer_text(app.draft)
	ui.task(&app.main.state, save_work, nil, new_clone(Save{path = strings.clone(join(app.folder, "socle", "system.json")), text = text}), save_lost)
	app.eval_due_ms = ui.now_ms() + EVAL_DELAY_MS
}

EVAL_DELAY_MS :: 1200.0

@(private = "file")
Save :: struct { path, text: string }

@(private = "file")
save_work :: proc(data: rawptr) {
	s := (^Save)(data)
	// (written beside, then renamed: an evaluation never reads half a file)
	tmp := fmt.tprintf("%s.new", s.path)
	if os.write_entire_file(tmp, s.text) == nil { _ = os.rename(tmp, s.path) }
	delete(s.path); delete(s.text)
	free(s)
}

@(private = "file")
save_lost :: proc(data: rawptr) { free(data) }

// The evaluator (README.md, "State machines"): one evaluation at a time; a newer draft makes one more after it. Its
// result replaces the info and says whether the draft is valid. Called before each build.
evaluator_step :: proc(app: ^App) {
	if app.source != .Folder || app.eval_due_ms == 0 || app.load != .Ready { return }
	if now := ui.now_ms(); now < app.eval_due_ms {
		ui.wake_within(&app.main.state, int(app.eval_due_ms - now) + 5)
		return
	}
	if app.evaluating { return }
	app.eval_due_ms = 0
	app.evaluating = true
	ui.task(&app.main.state, eval_work, eval_done, new_clone(Evaluation{app = app, folder = app.folder, host = app.host}), eval_lost)
}

@(private = "file")
Evaluation :: struct {
	app:          ^App,
	folder, host: string,
	info:         ^Info,
	why:          string,
}

@(private = "file")
eval_work :: proc(data: rawptr) {
	e := (^Evaluation)(data)
	text, why := evaluate(e.folder, e.host)
	if why != "" { e.why = why; return }
	info, perr := info_parse(text)
	delete(text)
	if info == nil { e.why = strings.clone(perr) } else { e.info = info }
}

@(private = "file")
eval_done :: proc(data: rawptr, _: u64) {
	e := (^Evaluation)(data)
	app := e.app
	app.evaluating = false
	delete(app.eval_error)
	app.eval_error = e.why
	if e.info != nil {
		info_destroy(app.info)
		app.info = e.info
		changes_update(app)
	}
	free(e)
	host_settle(app)
}

@(private = "file")
eval_lost :: proc(data: rawptr) { free(data) }

////////////////////////////////
// Updates

// Moves the folder's sources forward (nix flake update): the lock changes like any draft, and the review shows it.
updates_start :: proc(app: ^App) {
	if app.source == .Demo {
		app.lock_now["nixpkgs"] = app.lock_committed["nixpkgs"] + 7 * 86400
		changes_update(app)
		return
	}
	app.updating = true
	ui.task(&app.main.state, update_work, update_done, new_clone(Update{app = app, folder = app.folder}), update_lost)
}

@(private = "file")
Update :: struct { app: ^App, folder: string, why: string }

@(private = "file")
update_work :: proc(data: rawptr) {
	u := (^Update)(data)
	r := run({"nix", "flake", "update", "--flake", u.folder})
	delete(r.stdout)
	if !r.ok { u.why = nix_error(r.stderr) } else { delete(r.stderr) }
}

@(private = "file")
update_done :: proc(data: rawptr, _: u64) {
	u := (^Update)(data)
	app := u.app
	app.updating = false
	if u.why != "" {
		ui.announce(&app.announcer, .Bad, "The sources could not be updated", u.why)
		delete(u.why)
	}
	free(u)
	load_start(app)
}

@(private = "file")
update_lost :: proc(data: rawptr) { free(data) }

////////////////////////////////
// The demo

@(private = "file")
demo_load :: proc(app: ^App) {
	info, _ := info_parse(DEMO_INFO)
	info_destroy(app.info)
	app.info = info
	layer_destroy(&app.draft)
	layer_destroy(&app.committed)
	app.draft = layer_parse(DEMO_LAYER)
	app.committed = layer_parse(DEMO_LAYER)
	layer_destroy(&app.machine)
	app.machine = layer_parse(DEMO_MACHINE)
	delete(app.host)
	app.host = strings.clone(DEMO_HOST)
	app.load = .Ready
	if len(app.generations) == 0 { app.generations = demo_generations() }
	if len(app.lock_now) == 0 {
		// (the demo's sources: the catalogue of 11 November 2026)
		app.lock_now["nixpkgs"] = 1794355200
		app.lock_now["socle"] = 1795046400
		app.lock_committed["nixpkgs"] = 1794355200
		app.lock_committed["socle"] = 1795046400
	}
	changes_update(app)
}

@(private = "file")
demo_generations :: proc() -> [dynamic]Generation {
	out := make([dynamic]Generation)
	day :: 86400
	now :: i64(1795081920)   // (19 November 2026, 09:12: the demo's own clock)
	Item :: struct { n: int, ago: i64, title: string }
	items := [?]Item{
		{214, 0, "Added Krita"},
		{213, 3 * day, "Noé's account: limits on school days"},
		{212, 7 * day, "Software catalogue of 11 November"},
		{211, 10 * day, ""},
		{210, 17 * day, "The printer in the living room"},
		{209, 22 * day, "Template Family desktop 1.3"},
	}
	for it in items {
		append(&out, Generation{
			number = it.n, date = time.unix(now - it.ago, 0), title = strings.clone(it.title),
			revision = strings.clone(it.title == "" ? "" : "demo"), running = it.n == 214, default_ = it.n == 214,
			path = strings.clone(fmt.tprintf("/nix/store/demo-%d", it.n)),
		})
	}
	return out
}
