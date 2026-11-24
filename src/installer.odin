package socle

// The installer's window (src/md/features/installer.md): the steps of a new machine, its review, then the helper's
// install with its progress. `socle install` opens it; socle's Desktop image opens it at its start. What the machine
// has (its disks, its network, its time zones) comes from workers; the install itself is one worker job that writes
// the folder, then follows the helper's lines.

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"
import "core:strings"
import lucide "gt:lucide"
import "gt:ui"

Install_Page :: enum { Language, Network, Disk, Person, Template, Review, Installing }

INSTALL_PAGE_TITLES := [Install_Page]string{
	.Language = "Language", .Network = "Network", .Disk = "Disk", .Person = "You", .Template = "System",
	.Review = "Review", .Installing = "Install",
}

// A language: its locale, and the keyboard and time zone it suggests.
Language :: struct { title, locale, keyboard, zone: string }

LANGUAGES := [?]Language{
	{"English (United States)", "en_US.UTF-8", "us", "America/New_York"},
	{"English (United Kingdom)", "en_GB.UTF-8", "gb", "Europe/London"},
	{"Français", "fr_FR.UTF-8", "fr", "Europe/Paris"},
	{"Deutsch", "de_DE.UTF-8", "de", "Europe/Berlin"},
	{"Español", "es_ES.UTF-8", "es", "Europe/Madrid"},
	{"Italiano", "it_IT.UTF-8", "it", "Europe/Rome"},
	{"Português (Brasil)", "pt_BR.UTF-8", "br", "America/Sao_Paulo"},
	{"Nederlands", "nl_NL.UTF-8", "us", "Europe/Amsterdam"},
	{"Polski", "pl_PL.UTF-8", "pl", "Europe/Warsaw"},
	{"Svenska", "sv_SE.UTF-8", "se", "Europe/Stockholm"},
}

// A keyboard: its name, its XKB layout.
KEYBOARDS := [?][2]string{
	{"English (US)", "us"}, {"English (UK)", "gb"}, {"French", "fr"}, {"German", "de"}, {"Spanish", "es"},
	{"Italian", "it"}, {"Portuguese (Brazil)", "br"}, {"Polish", "pl"}, {"Swedish", "se"}, {"Swiss", "ch"},
	{"Belgian", "be"}, {"Canadian (French)", "ca"}, {"Dvorak (US)", "us(dvorak)"},
}

Disk_Info :: struct {
	path:   string,   // by its /dev/disk/by-id link when it has one
	model:  string,
	size:   i64,
	in_use: string,   // why it cannot be chosen ("": it can)
}

Wifi :: struct { ssid: string, signal: int, secured: bool }

Installer :: struct {
	page:        Install_Page,
	language:    int,
	keyboard:    int,
	zone:        string,   // an IANA name (owned): the language's until the person picks another
	// the network
	online:      bool,
	checked:     bool,   // the network's state is known
	wifis:       [dynamic]Wifi,
	wifi:        int,
	wifi_key:    ui.Line_Edit,
	connecting:  bool,
	net_error:   string,
	// the disk
	disks:       [dynamic]Disk_Info,
	disks_read:  bool,
	disk:        int,
	encrypt:     bool,
	passphrase:  ui.Line_Edit,
	passphrase2: ui.Line_Edit,
	show_secret: bool,
	// the person
	name:        ui.Line_Edit,
	login:       ui.Line_Edit,
	machine:     ui.Line_Edit,
	password:    ui.Line_Edit,
	password2:   ui.Line_Edit,
	show_pass:   bool,
	// the system
	gallery:     [dynamic]Gallery_Entry,   // socle's templates of a whole system
	template:    int,
	// the install
	step:        Install_Step,
	progress:    Progress,
	running:     bool,
	done:        bool,
	why:         string,
	attempt:     int,
	started_ms:  f64,
}

installer_open :: proc(app: ^App) {
	ins := new(Installer)
	app.installer = ins
	ins.disk = -1
	ins.gallery = templates_of(.System)
	zone_suggest(ins)
	if app.source == .Demo {
		installer_demo_machine(ins)
		return
	}
	ui.task(&app.main.state, machine_work, machine_done, new_clone(Machine_Read{app = app}), proc(d: rawptr) { free(d) })
}

installer_close :: proc(app: ^App) {
	ins := app.installer
	if ins == nil { return }
	delete(ins.zone)
	wifis_clear(&ins.wifis)
	delete(ins.wifis)
	disks_clear(&ins.disks)
	delete(ins.disks)
	for f in ([]^ui.Line_Edit{&ins.wifi_key, &ins.passphrase, &ins.passphrase2, &ins.name, &ins.login, &ins.machine, &ins.password, &ins.password2}) {
		ui.line_edit_destroy(f)
	}
	gallery_destroy(&ins.gallery)
	delete(ins.net_error)
	delete(ins.why)
	delete(ins.progress.doing)
	free(ins)
	app.installer = nil
}

@(private = "file")
disks_clear :: proc(ds: ^[dynamic]Disk_Info) {
	for d in ds { delete(d.path); delete(d.model); delete(d.in_use) }
	clear(ds)
}

@(private = "file")
wifis_clear :: proc(ws: ^[dynamic]Wifi) {
	for w in ws { delete(w.ssid) }
	clear(ws)
}

////////////////////////////////
// What the machine has: read on a worker

@(private = "file")
Machine_Read :: struct {
	app:    ^App,
	disks:  [dynamic]Disk_Info,
	wifis:  [dynamic]Wifi,
	online: bool,
}

@(private = "file")
machine_work :: proc(data: rawptr) {
	m := (^Machine_Read)(data)
	m.disks = disks_read()
	m.online, m.wifis = network_read()
}

@(private = "file")
machine_done :: proc(data: rawptr, _: u64) {
	m := (^Machine_Read)(data)
	ins := m.app.installer
	if ins == nil { free(m); return }
	disks_clear(&ins.disks)
	delete(ins.disks)
	ins.disks = m.disks
	ins.disks_read = true
	wifis_clear(&ins.wifis)
	delete(ins.wifis)
	ins.wifis = m.wifis
	ins.online, ins.checked = m.online, true
	free(m)
}

// The disks of this machine (lsblk), each with why it cannot be chosen: a disk that holds anything mounted (the live
// image's own medium) or too small for a system.
disks_read :: proc() -> [dynamic]Disk_Info {
	out := make([dynamic]Disk_Info)
	r := run({"lsblk", "-J", "-b", "-o", "PATH,SIZE,MODEL,TYPE,MOUNTPOINTS,ID-LINK"}, allocator = context.temp_allocator)
	if !r.ok { return out }
	v, err := json.parse_string(r.stdout, parse_integers = true, allocator = context.temp_allocator)
	if err != nil { return out }
	for d in arr(at(v, {"blockdevices"})) {
		if str(at(d, {"type"})) != "disk" { continue }
		path := str(at(d, {"path"}))
		if strings.contains(path, "zram") { continue }
		info := Disk_Info{model = strings.clone(strings.trim_space(str(at(d, {"model"})))), size = i64(num(at(d, {"size"})))}
		link := str(at(d, {"id-link"}))
		info.path = link != "" ? fmt.aprintf("/dev/disk/by-id/%s", link) : strings.clone(path)
		switch {
		case mounted_in(d): info.in_use = strings.clone("In use: the install medium, or mounted")
		case info.size < 16 << 30: info.in_use = strings.clone("Too small: a system needs 16 GB or more")
		}
		if info.model == "" { delete(info.model); info.model = strings.clone(path) }
		append(&out, info)
	}
	return out
}

// Anything of this block device or of its partitions is mounted.
@(private = "file")
mounted_in :: proc(d: json.Value) -> bool {
	for m in arr(at(d, {"mountpoints"})) { if str(m) != "" { return true } }
	for c in arr(at(d, {"children"})) { if mounted_in(c) { return true } }
	return false
}

// The network: full connectivity, and the Wi-Fi networks in reach (NetworkManager's).
network_read :: proc() -> (online: bool, wifis: [dynamic]Wifi) {
	wifis = make([dynamic]Wifi)
	c := run({"nmcli", "-t", "-f", "CONNECTIVITY", "general"}, allocator = context.temp_allocator)
	// (no NetworkManager: a wired machine set up by hand, or a test's; the install says if the network is missing)
	if !c.ok { return true, wifis }
	online = strings.trim_space(c.stdout) == "full"
	l := run({"nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"}, allocator = context.temp_allocator)
	for line in strings.split_lines(l.stdout, context.temp_allocator) {
		// (nmcli escapes a colon of a name as \:)
		fields := make([dynamic]string, context.temp_allocator)
		b := strings.builder_make(context.temp_allocator)
		for i := 0; i < len(line); i += 1 {
			if line[i] == '\\' && i + 1 < len(line) { strings.write_byte(&b, line[i + 1]); i += 1; continue }
			if line[i] == ':' { append(&fields, strings.clone(strings.to_string(b), context.temp_allocator)); strings.builder_reset(&b); continue }
			strings.write_byte(&b, line[i])
		}
		append(&fields, strings.to_string(b))
		if len(fields) < 3 || fields[0] == "" { continue }
		signal, _ := strconv.parse_int(fields[1])
		seen := false
		for w in wifis { seen ||= w.ssid == fields[0] }
		if !seen { append(&wifis, Wifi{ssid = strings.clone(fields[0]), signal = signal, secured = fields[2] != "" && fields[2] != "--"}) }
	}
	return
}

@(private = "file")
installer_demo_machine :: proc(ins: ^Installer) {
	append(&ins.disks, Disk_Info{path = strings.clone("/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB"), model = strings.clone("Samsung SSD 990 PRO"), size = 2000398934016, in_use = strings.clone("")})
	append(&ins.disks, Disk_Info{path = strings.clone("/dev/disk/by-id/usb-SanDisk_Ultra"), model = strings.clone("SanDisk Ultra"), size = 30752636928, in_use = strings.clone("In use: the install medium, or mounted")})
	append(&ins.wifis, Wifi{ssid = strings.clone("Maison"), signal = 82, secured = true})
	ins.online, ins.checked, ins.disks_read = true, true, true
}

// The time zone that the language suggests.
@(private = "file")
zone_suggest :: proc(ins: ^Installer) {
	delete(ins.zone)
	ins.zone = strings.clone(LANGUAGES[ins.language].zone)
}

////////////////////////////////
// The plan

// The machine's name: the one typed, else one from the login.
@(private = "file")
machine_name :: proc(ins: ^Installer) -> string {
	typed := strings.trim_space(ui.line_edit_string(&ins.machine))
	if typed != "" { return typed }
	login := strings.trim_space(ui.line_edit_string(&ins.login))
	return fmt.tprintf("%s-computer", login != "" ? login : "my")
}

// The plan of the window's choices, its password not yet hashed (plan_check then wants a hash: "$" stands for it).
@(private = "file")
installer_plan :: proc(ins: ^Installer) -> Plan {
	lang := LANGUAGES[ins.language]
	p := Plan{
		host = machine_name(ins), locale = lang.locale, keyboard = KEYBOARDS[ins.keyboard][1],
		zone = ins.zone,
		login = strings.trim_space(ui.line_edit_string(&ins.login)), name = strings.trim_space(ui.line_edit_string(&ins.name)),
		hash = "$", encrypt = ins.encrypt, passphrase = ui.line_edit_string(&ins.passphrase),
	}
	if ins.disk >= 0 && ins.disk < len(ins.disks) { p.disk = ins.disks[ins.disk].path }
	if ins.template < len(ins.gallery) { p.template = ins.gallery[ins.template].ref }
	if p.name == "" { p.name = p.login }
	return p
}

// What stops the page from going on ("": nothing), in a person's words.
@(private = "file")
page_blocked :: proc(ins: ^Installer) -> string {
	switch ins.page {
	case .Language:
		// (the language always gives a time zone: nothing to choose before going on)
	case .Network:
		if !ins.online { return "socle downloads the system: connect to a network." }
	case .Disk:
		if ins.disk < 0 { return "Choose the disk." }
		if ins.encrypt {
			p := ui.line_edit_string(&ins.passphrase)
			if len(p) < 8 { return "The passphrase needs 8 characters or more." }
			if p != ui.line_edit_string(&ins.passphrase2) { return "The two passphrases differ." }
		}
	case .Person:
		p := installer_plan(ins)
		probe := p
		probe.disk, probe.template, probe.passphrase = "/dev/x", "socle#x", "--------"
		if why := plan_check(probe); why != "" { return why }
		if len(ui.line_edit_string(&ins.password)) == 0 { return "Choose a password." }
		if ui.line_edit_string(&ins.password) != ui.line_edit_string(&ins.password2) { return "The two passwords differ." }
	case .Template, .Review, .Installing:
	}
	return ""
}

////////////////////////////////
// The install: one worker job

@(private = "file")
Install_Job :: struct {
	app:      ^App,
	plan:     Plan,
	password: string,
	dir:      string,
	// the worker's own
	log:      Nix_Log,
	tail:     [dynamic]string,
	posted:   f64,
	// its answer
	why:      string,
}

@(private = "file")
Install_Post :: struct { step: Install_Step, has_step: bool, progress: Progress }

@(private = "file")
installer_start :: proc(app: ^App) {
	ins := app.installer
	if ins.running { return }
	ins.page, ins.running, ins.done = .Installing, true, false
	ins.step = .Check
	delete(ins.why); ins.why = ""
	delete(ins.progress.doing); ins.progress = {}
	ins.started_ms = ui.now_ms()
	ins.attempt += 1
	if app.source == .Demo { return }
	job := new(Install_Job)
	job.app = app
	job.plan = plan_clone(installer_plan(ins))
	job.password = strings.clone(ui.line_edit_string(&ins.password))
	job.dir = fmt.aprintf("/tmp/socle-install-%d-%d", os.get_pid(), ins.attempt)
	ui.task(&app.main.state, install_work, install_done, job, proc(d: rawptr) { free(d) })
}

@(private = "file")
plan_clone :: proc(p: Plan) -> Plan {
	c := p
	c.host, c.template, c.locale, c.keyboard = strings.clone(p.host), strings.clone(p.template), strings.clone(p.locale), strings.clone(p.keyboard)
	c.zone, c.login, c.name, c.disk = strings.clone(p.zone), strings.clone(p.login), strings.clone(p.name), strings.clone(p.disk)
	c.passphrase = strings.clone(p.passphrase)
	return c
}

@(private = "file")
plan_free :: proc(p: Plan) {
	delete(p.host); delete(p.template); delete(p.locale); delete(p.keyboard); delete(p.zone)
	delete(p.login); delete(p.name); delete(p.disk); delete(p.passphrase); delete(p.hash)
}

@(private = "file")
install_work :: proc(data: rawptr) {
	j := (^Install_Job)(data)
	// (the password on mkpasswd's standard input: never on a command line)
	h := run_input({"mkpasswd", "--method=yescrypt", "--stdin"}, j.password)
	if !h.ok { j.why = strings.clone("The password could not be hashed (mkpasswd)."); return }
	j.plan.hash = strings.clone(strings.trim_space(h.stdout))
	if why := plan_write(j.dir, j.plan); why != "" { j.why = strings.clone(why); return }
	nix_log_init(&j.log)
	defer nix_log_destroy(&j.log)
	r := install_run(j.dir, install_line, j)
	if !r.ok {
		b := strings.builder_make()
		if e := nix_log_errors(&j.log); e != "" { strings.write_string(&b, e); strings.write_byte(&b, '\n') }
		for t in j.tail { strings.write_string(&b, t); strings.write_byte(&b, '\n') }
		j.why = strings.to_string(b)
		if strings.trim_space(j.why) == "" { delete(j.why); j.why = strings.clone("The install stopped.") }
		if r.code == 126 || r.code == 127 { delete(j.why); j.why = strings.clone("An administrator's password is needed to install.") }
	}
	for t in j.tail { delete(t) }
	delete(j.tail)
}

// One line of the helper: a step, nix's log, or a program's words (the last ones say why an install stopped).
@(private = "file")
install_line :: proc(user: rawptr, text: string) {
	j := (^Install_Job)(user)
	if step, ok := install_step_of(text); ok {
		post := new(Install_Post)
		post^ = {step = step, has_step = true}
		if !ui.post(&j.app.main.state, install_post, post) { free(post) }
		for t in j.tail { delete(t) }
		clear(&j.tail)
		return
	}
	if nix_log_line(&j.log, text) {
		now := ui.now_ms()
		if now - j.posted < 100 { return }
		j.posted = now
		post := new(Install_Post)
		post.progress = j.log.progress
		post.progress.doing = strings.clone(j.log.progress.doing)
		if !ui.post(&j.app.main.state, install_post, post) { delete(post.progress.doing); free(post) }
		return
	}
	if len(j.tail) >= 12 { delete(j.tail[0]); ordered_remove(&j.tail, 0) }
	append(&j.tail, strings.clone(text))
}

@(private = "file")
install_post :: proc(data: rawptr, _: u64) {
	p := (^Install_Post)(data)
	app := the_app
	if app != nil && app.installer != nil {
		ins := app.installer
		if p.has_step {
			ins.step = p.step
			delete(ins.progress.doing); ins.progress = {}
		} else {
			delete(ins.progress.doing)
			ins.progress = p.progress
			p.progress.doing = ""
		}
	}
	delete(p.progress.doing)
	free(p)
}

@(private = "file")
install_done :: proc(data: rawptr, _: u64) {
	j := (^Install_Job)(data)
	if ins := j.app.installer; ins != nil {
		ins.running = false
		if j.why == "" {
			ins.done, ins.step = true, .Done
		} else {
			delete(ins.why)
			ins.why = strings.clone(j.why)
		}
	}
	delete(j.why); delete(j.password); delete(j.dir)
	plan_free(j.plan)
	free(j)
}

// The demo's install: its steps one after another, its build's progress drawn from the clock.
@(private = "file")
DEMO_STEP_MS := [Install_Step]f64{.Check = 900, .Disk = 1800, .Folder = 600, .Hardware = 900, .Build = 6000, .Install = 1800, .Done = 0}

installer_step :: proc(app: ^App) {
	ins := app.installer
	if ins == nil || !ins.running || app.source != .Demo { return }
	ui.keep_animating()
	elapsed := ui.now_ms() - ins.started_ms
	at := 0.0
	for s in Install_Step {
		d := DEMO_STEP_MS[s]
		if s == .Done || elapsed < at + d {
			ins.step = s
			if s == .Build {
				k := (elapsed - at) / d
				ins.progress.paths_expected, ins.progress.paths_done = 1412, int(1412 * k)
				ins.progress.builds_expected, ins.progress.builds_done = 9, int(9 * k)
			}
			if s == .Done { ins.running, ins.done = false, true }
			return
		}
		at += d
	}
}

////////////////////////////////
// The window

installer_build :: proc(app: ^App, em: f32) {
	ins := app.installer
	installer_step(app)
	ui.next({width = ui.fill(), height = ui.fill(), axis = .Y})
	if ui.column(id = "###installer") {
		installer_bar(app, em)
		ui.next({width = ui.fill(), height = ui.fill()})
		if ui.scroll_y("###install_scroll") {
			ui.next({width = ui.fill(), height = ui.children_sum(), axis = .X})
			if ui.row(id = "###install_margin") {
				ui.spacer(ui.fill())
				ui.next({width = ui.px(math.round(em * 44)), height = ui.children_sum(), axis = .Y})
				if ui.column(id = "###install_page") {
					ui.spacer(ui.px(em * 1.6))
					wizard_steps(ins, em)
					ui.spacer(ui.px(em * 2))
					switch ins.page {
					case .Language:   language_page(app, em)
					case .Network:    network_page(app, em)
					case .Disk:       disk_page(app, em)
					case .Person:     person_page(app, em)
					case .Template:   template_page(app, em)
					case .Review:     review_page(app, em)
					case .Installing: installing_page(app, em)
					}
					ui.spacer(ui.px(em * 1.6))
				}
				ui.spacer(ui.fill())
			}
		}
		if ins.page != .Installing { wizard_buttons(app, em) }
	}
}

@(private = "file")
installer_bar :: proc(app: ^App, em: f32) {
	if ui.tags("bar") {
		ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 2.8)), radius = 0})
		if ui.title_bar("###top", {.Draw_Background, .Draw_Side_Bottom}) {
			ui.spacer(ui.px(em * 0.9))
			ui.next({width = ui.px(em * 1.5), height = ui.pct(1), font = ui.lucide_icons(), text_align = .Center, fg = ui.color("accent")})
			ui.build_box({.Draw_Text, .No_Text_Trunc}, lucide.LAYERS_3 + "###mark")
			ui.spacer(ui.px(em * 0.35))
			ui.next({width = ui.text_size(), height = ui.pct(1), font_size = math.round(em * 1.05), text_pad = 0})
			ui.label("socle###brand")
			ui.spacer(ui.fill())
			if app.source == .Demo {
				if ui.tags("weak") {
					ui.next({width = ui.text_size(0, 0), height = ui.pct(1), text_pad = 0})
					ui.label("demo###where")
				}
				ui.spacer(ui.px(em * 0.8))
			}
			ui.window_buttons()
		}
	}
}

// Where the person is: the steps before the install, done, under way, to come.
@(private = "file")
wizard_steps :: proc(ins: ^Installer, em: f32) {
	steps := make([dynamic]ui.Stepper_Step, context.temp_allocator)
	for p in Install_Page {
		state: ui.Stepper_State = .Pending
		switch {
		case p == .Installing && ins.done:       state = .Done
		case p == .Installing && ins.why != "":  state = .Failed
		case p == .Network && ins.online && p != ins.page: state = .Skipped
		case p == ins.page:                       state = .Active
		case p < ins.page:                        state = .Done
		}
		append(&steps, ui.Stepper_Step{label = INSTALL_PAGE_TITLES[p], state = state})
	}
	ui.next({width = ui.fill()})
	ui.stepper("###wizard_steps", steps[:])
}

@(private = "file")
wizard_buttons :: proc(app: ^App, em: f32) {
	ins := app.installer
	if ui.tags("bar") {
		ui.next({width = ui.fill(), height = ui.px(ui.dense(em * 3.6)), axis = .X, cross = .Center, radius = 0})
		if ui.row(flags = {.Draw_Background, .Draw_Side_Top}, id = "###wizard_bar") {
			ui.spacer(ui.fill())
			ui.next({width = ui.px(math.round(em * 44)), height = ui.pct(1), axis = .X, cross = .Center})
			if ui.row(id = "###wizard_bar_inner") {
				blocked := page_blocked(ins)
				if ui.tags("weak") {
					ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###wizard_blocked", blocked))
				}
				if ins.page > .Language {
					if ui.button("wizard_back", "Back", lucide.ARROW_LEFT).clicked { ins.page = page_before(ins) }
					ui.spacer(ui.px(em * 0.6))
				}
				if ins.page == .Review {
					d := ins.disks[ins.disk]
					if ui.button("install_go", fmt.tprintf("Erase %s, %s, and install", d.model, size_words(d.size)), lucide.HARD_DRIVE_DOWNLOAD, {intent = .Danger}).clicked {
						installer_start(app)
					}
				} else if ui.button("wizard_next", "Next", lucide.ARROW_RIGHT, {intent = .Primary, disabled = blocked != ""}).clicked {
					ins.page = page_after(ins)
				}
			}
			ui.spacer(ui.fill())
		}
	}
}

// The pages in order; the network's is left out while the machine is online.
@(private = "file")
page_after :: proc(ins: ^Installer) -> Install_Page {
	next := Install_Page(int(ins.page) + 1)
	if next == .Network && ins.online { next = .Disk }
	return next
}

@(private = "file")
page_before :: proc(ins: ^Installer) -> Install_Page {
	before := Install_Page(int(ins.page) - 1)
	if before == .Network && ins.online { before = .Language }
	return before
}

// "2 TB", "512 GB": a disk's size as its maker says it (powers of ten).
size_words :: proc(bytes: i64) -> string {
	gb := f64(bytes) / 1e9
	if gb >= 1000 { return fmt.tprintf("%.0f TB", gb / 1000) }
	return fmt.tprintf("%.0f GB", gb)
}

// A field and its label, one above the other.
@(private = "file")
field :: proc(id, label: string, f: ^ui.Line_Edit, o: ui.Line_Edit_Options, em: f32) {
	ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
	ui.label(fmt.tprintf("%s###%s_label", label, id))
	ui.spacer(ui.px(em * 0.35))
	ui.next({width = ui.fill(), height = ui.px(ui.control_height())})
	ui.line_edit(fmt.tprintf("###%s", id), f, o)
	ui.spacer(ui.px(em * 0.9))
}

@(private = "file")
language_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	page_head("Welcome", "socle installs a whole system on this computer.", em)
	section("Language", em)
	titles := make([dynamic]string, context.temp_allocator)
	for l in LANGUAGES { append(&titles, l.title) }
	ui.next({width = ui.fill()})
	if ui.dropdown("###language", titles[:], &ins.language) {
		// (the language suggests its keyboard and its time zone)
		for k, i in KEYBOARDS { if k[1] == LANGUAGES[ins.language].keyboard { ins.keyboard = i; keyboard_apply(app) } }
		zone_suggest(ins)
	}
	section("Keyboard", em)
	boards := make([dynamic]string, context.temp_allocator)
	for k in KEYBOARDS { append(&boards, k[0]) }
	ui.next({width = ui.fill()})
	if ui.dropdown("###keyboard", boards[:], &ins.keyboard) { keyboard_apply(app) }
	ui.spacer(ui.px(em * 0.5))
	weak("The same keyboard at each start, where the disk's passphrase is typed.", "keyboard_note")
	section("Time zone", em)
	if picked, ok := zone_picker(app, ins.zone, false, em); ok {
		delete(ins.zone)
		ins.zone = strings.clone(picked)
	}
}

// The live session's keyboard follows the choice (sway's, on socle's image): what is typed here is what the
// installed machine reads.
@(private = "file")
keyboard_apply :: proc(app: ^App) {
	if app.source == .Demo { return }
	layout := strings.clone(KEYBOARDS[app.installer.keyboard][1])
	ui.task(&app.main.state, proc(d: rawptr) {
		l := (^string)(d)
		_ = run({"swaymsg", "input", "type:keyboard", "xkb_layout", l^}, allocator = context.temp_allocator)
	}, proc(d: rawptr, _: u64) { l := (^string)(d); delete(l^); free(l) }, new_clone(layout), proc(d: rawptr) { free(d) })
}

@(private = "file")
network_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	page_head("Network", "socle downloads the system you choose.", em)
	ui.spacer(ui.px(em * 1.2))
	if ins.online {
		note_well("online", lucide.WIFI, .Green, "Connected", "", em)
		return
	}
	if len(ins.wifis) == 0 {
		weak("No network: plug in a cable, or turn the Wi-Fi on.", "no_network")
	} else if ui.list_card("###wifis") {
		for w, i in ins.wifis {
			if ui.card_row(fmt.tprintf("###wifi%d", i)) {
				ui.radio(fmt.tprintf("###wifi_pick%d", i), w.ssid, &ins.wifi, i)
				ui.spacer(ui.fill())
				if ui.tags("weak") {
					ui.next({width = ui.text_size(0, 0), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%d %%%s###wifi_signal%d", w.signal, w.secured ? ", locked" : "", i))
				}
			}
		}
	}
	ui.spacer(ui.px(em))
	if ins.wifi < len(ins.wifis) && ins.wifis[ins.wifi].secured {
		field("wifi_key", "Password", &ins.wifi_key, {kind = .Secret, reveal = &ins.show_secret}, em)
	}
	if ins.net_error != "" { note_well("net_error", lucide.ALERT_TRIANGLE, .Red, "No connection", ins.net_error, em); ui.spacer(ui.px(em * 0.8)) }
	if ui.button("wifi_connect", "Connect", lucide.WIFI, {busy = ins.connecting, disabled = len(ins.wifis) == 0}).clicked { wifi_connect(app) }
	ui.spacer(ui.px(em * 0.5))
	if ui.button("network_again", "Look again", lucide.REFRESH_CW, {face = .Ghost}).clicked {
		ui.task(&app.main.state, machine_work, machine_done, new_clone(Machine_Read{app = app}), proc(d: rawptr) { free(d) })
	}
}

@(private = "file")
Wifi_Join :: struct { app: ^App, ssid, key, why: string }

@(private = "file")
wifi_connect :: proc(app: ^App) {
	ins := app.installer
	if ins.connecting || ins.wifi >= len(ins.wifis) { return }
	ins.connecting = true
	j := new(Wifi_Join)
	j^ = {app = app, ssid = strings.clone(ins.wifis[ins.wifi].ssid), key = strings.clone(ui.line_edit_string(&ins.wifi_key))}
	ui.task(&app.main.state, proc(d: rawptr) {
		j := (^Wifi_Join)(d)
		cmd := make([dynamic]string, context.temp_allocator)
		append(&cmd, "nmcli", "device", "wifi", "connect", j.ssid)
		if j.key != "" { append(&cmd, "password", j.key) }
		r := run(cmd[:], allocator = context.temp_allocator)
		if !r.ok { j.why = strings.clone(strings.trim_space(r.stderr != "" ? r.stderr : r.stdout)) }
	}, proc(d: rawptr, _: u64) {
		j := (^Wifi_Join)(d)
		if ins := j.app.installer; ins != nil {
			ins.connecting = false
			delete(ins.net_error)
			ins.net_error = strings.clone(j.why)
			if j.why == "" { ins.online = true }
		}
		delete(j.ssid); delete(j.key); delete(j.why)
		free(j)
	}, j, proc(d: rawptr) { free(d) })
}

@(private = "file")
disk_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	page_head("Disk", "The whole disk goes to the new system.", em)
	ui.spacer(ui.px(em * 1.2))
	if !ins.disks_read {
		ui.button("###disks_busy", "Reading the disks", o = {face = .Ghost, busy = true})
		return
	}
	if ui.list_card("###disks") {
		for d, i in ins.disks {
			if ui.card_row(fmt.tprintf("###disk%d", i)) {
				if d.in_use == "" {
					ui.radio(fmt.tprintf("###disk_pick%d", i), "", &ins.disk, i)
					ui.spacer(ui.px(em * 0.4))
				} else {
					ui.spacer(ui.px(em * 1.6))
				}
				setting_words(fmt.tprintf("disk_%d", i), fmt.tprintf("%s, %s", d.model, size_words(d.size)), d.in_use, false, em)
			}
		}
	}
	section("Encryption", em)
	ui.next({width = ui.fill(), height = ui.px(em * 2.1)})
	ui.toggle("###encrypt", "Encrypt the disk: a passphrase at each start", &ins.encrypt)
	if ins.encrypt {
		ui.spacer(ui.px(em * 0.8))
		field("passphrase", "Passphrase", &ins.passphrase, {kind = .Secret, reveal = &ins.show_secret}, em)
		field("passphrase2", "The same passphrase again", &ins.passphrase2, {kind = .Secret}, em)
		weak("Nobody can read the disk without it, socle neither: keep it somewhere safe.", "passphrase_note")
	}
}

@(private = "file")
person_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	page_head("You", "The first account; it administers the computer.", em)
	ui.spacer(ui.px(em * 1.2))
	field("full_name", "Your name", &ins.name, {placeholder = "Ada Lovelace"}, em)
	field("login", "Login", &ins.login, {placeholder = "ada"}, em)
	field("password", "Password", &ins.password, {kind = .Secret, reveal = &ins.show_pass}, em)
	field("password2", "The same password again", &ins.password2, {kind = .Secret}, em)
	field("machine_name", "This computer's name", &ins.machine, {placeholder = machine_name(ins)}, em)
}

@(private = "file")
template_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	page_head("System", "What the computer is for. Every setting can change later.", em)
	ui.spacer(ui.px(em * 1.2))
	if ui.list_card("###templates") {
		for t, i in ins.gallery {
			if ui.card_row(fmt.tprintf("###template_row%d", i)) {
				ui.radio(fmt.tprintf("###template_pick%d", i), "", &ins.template, i)
				ui.spacer(ui.px(em * 0.4))
				setting_words(fmt.tprintf("template_%d", i), t.title, t.description, false, em)
			}
		}
	}
}

@(private = "file")
review_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	p := installer_plan(ins)
	d := ins.disks[ins.disk]
	page_head("Review", "Nothing has changed yet.", em)
	ui.spacer(ui.px(em * 1.2))
	note_well("erase", lucide.ALERT_TRIANGLE, .Red, fmt.tprintf("Everything on %s, %s, is erased", d.model, size_words(d.size)),
		ins.encrypt ? "Then the disk is encrypted: its passphrase is asked at each start." : "", em)
	ui.spacer(ui.px(em))
	if ui.list_card("###review") {
		rows := [][2]string{
			{"System", ins.gallery[ins.template].title},
			{"Account", fmt.tprintf("%s (%s), administrator", p.name, p.login)},
			{"Computer", p.host},
			{"Language", LANGUAGES[ins.language].title},
			{"Keyboard", KEYBOARDS[ins.keyboard][0]},
			{"Time zone", p.zone},
		}
		for r, i in rows {
			if ui.card_row(fmt.tprintf("###review%d", i)) {
				if ui.tags("weak") {
					ui.next({width = ui.px(em * 9), height = ui.text_size(), text_pad = 0})
					ui.label(fmt.tprintf("%s###review_key%d", r[0], i))
				}
				ui.next({width = ui.fill(), height = ui.text_size(), text_pad = 0})
				ui.label(fmt.tprintf("%s###review_value%d", r[1], i))
			}
		}
	}
}

@(private = "file")
installing_page :: proc(app: ^App, em: f32) {
	ins := app.installer
	switch {
	case ins.done: page_head("socle is installed", "Remove the install medium, then restart.", em)
	case ins.why != "": page_head("The install stopped", "", em)
	case: page_head("Installing", "The computer can be left alone: it takes a few minutes.", em)
	}
	ui.spacer(ui.px(em * 1.2))
	steps := make([dynamic]ui.Stepper_Step, context.temp_allocator)
	for s in Install_Step {
		if s == .Done { continue }
		state: ui.Stepper_State = .Pending
		switch {
		case ins.done || s < ins.step:      state = .Done
		case s == ins.step && ins.why != "": state = .Failed
		case s == ins.step:                  state = .Active
		}
		detail := ""
		if s == .Build && state == .Active { detail = install_progress_words(ins) }
		append(&steps, ui.Stepper_Step{label = install_step_words(s), detail = detail, state = state})
	}
	ui.next({width = ui.fill()})
	ui.stepper("###install_steps", steps[:], {direction = .Down})
	ui.spacer(ui.px(em * 1.4))
	switch {
	case ins.done:
		if ui.button("restart", "Restart", lucide.POWER, {intent = .Primary}).clicked { restart(app) }
	case ins.why != "":
		note_well("install_failed", lucide.ALERT_TRIANGLE, .Red, "What the install said", ins.why, em)
		ui.spacer(ui.px(em))
		if ui.button("install_back", "Back to the review", lucide.ARROW_LEFT).clicked { ins.page = .Review }
	}
}

// The build's progress in words: what is downloaded and built of what is needed.
@(private = "file")
install_progress_words :: proc(ins: ^Installer) -> string {
	p := ins.progress
	if p.paths_expected == 0 && p.builds_expected == 0 { return "Working out what is needed" }
	return fmt.tprintf("%d of %d downloaded, %d of %d built", p.paths_done, p.paths_expected, p.builds_done, p.builds_expected)
}

@(private = "file")
restart :: proc(app: ^App) {
	if app.source == .Demo { ui.announce(&app.announcer, .Info, "The demo does not restart", ""); return }
	ui.task(&app.main.state, proc(_: rawptr) { _ = run({"systemctl", "reboot"}, allocator = context.temp_allocator) }, proc(_: rawptr, _: u64) {}, nil, proc(_: rawptr) {})
}
