package socle

// The big lists: every package of the locked Nixpkgs (the Apps page), every option of the system (All settings) and
// every time zone (Region), each read once on a worker and kept; each query is searched on a worker, numbered: only
// the newest answer shows (src/md/features/apps.md, all-settings.md, region.md).

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:mem/virtual"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"
import "core:time/timezone"
import "gt:ui"

Index_State :: enum { Absent, Building, Ready, Failed }

Index_Kind :: enum { Packages, Options, Zones }

Entry :: struct {
	key:         string,   // a package's attribute, an option's path, a zone's IANA name
	name:        string,   // a package's pname; an option's type; a zone's offset now ("UTC+1")
	version:     string,   // a package's version; an option's default, as Nix writes it
	description: string,   // a zone's: its name in words and its offset, what a search reads
	offset:      int,      // a zone's offset from UTC now, in seconds
}

Index :: struct {
	state:   Index_State,
	why:     string,
	arena:   virtual.Arena,
	entries: [dynamic]Entry,
	// the newest query and its answer
	asked:   int,
	query:   string,
	hits:    [dynamic]Entry,   // copies of entries (the index's strings: it outlives every answer)
	answered: int,
}

HITS_MAX :: 120

@(private = "file")
Index_Build :: struct {
	app:   ^App,
	index: ^Index,
	kind:  Index_Kind,
	from:  string,   // the locked Nixpkgs, or the folder and its host
	host:  string,
	arena: virtual.Arena,
	entries: [dynamic]Entry,
	why:   string,
}

// The index asked for when a page needs it; read once per session. The zones are the system's, not the folder's: the
// demo has them too.
index_need :: proc(app: ^App, index: ^Index, kind: Index_Kind) {
	if index.state != .Absent { return }
	if kind != .Zones && (app.source != .Folder || app.info == nil) { return }
	index.state = .Building
	b := new(Index_Build)
	b.app, b.index, b.kind = app, index, kind
	switch kind {
	case .Options:  b.from, b.host = strings.clone(app.folder), strings.clone(app.host)
	case .Packages: b.from = strings.clone(app.info.nixpkgs)
	case .Zones:
	}
	ui.task(&app.main.state, index_work, index_done, b, index_lost)
}

@(private = "file")
index_work :: proc(data: rawptr) {
	b := (^Index_Build)(data)
	if virtual.arena_init_growing(&b.arena) != nil { b.why = strings.clone("no memory"); return }
	a := virtual.arena_allocator(&b.arena)
	b.entries = make([dynamic]Entry, a)
	switch b.kind {
	case .Packages:
		// (nix's evaluation cache keeps the search of a locked Nixpkgs: a minute the first time, at once after)
		r := run({"nix", "search", "--json", "--no-warn-dirty", fmt.tprintf("path:%s", b.from), "^"}, allocator = a)
		if !r.ok { b.why = nix_error(strings.clone(r.stderr)); return }
		v, err := json.parse_string(r.stdout, allocator = a)
		if err != nil { b.why = strings.clone("nix search's answer is not JSON"); return }
		all, _ := v.(json.Object)
		for k, p in all {
			attr := k
			if at := strings.index(k, "-linux."); at >= 0 { attr = k[at + len("-linux."):] }
			append(&b.entries, Entry{key = attr, name = str(at_(p, "pname")), version = str(at_(p, "version")), description = str(at_(p, "description"))})
		}
	case .Options:
		// (the name quoted: a home's holds an @)
		target := fmt.tprintf("%s#socleOptions.\"%s\"", b.from, b.host)
		r := run({"nix", "build", "--no-link", "--print-out-paths", "--no-warn-dirty", target}, allocator = a)
		if !r.ok { b.why = nix_error(strings.clone(r.stderr)); return }
		path := join(strings.trim_space(r.stdout), "share", "doc", "nixos", "options.json")
		text, rerr := os.read_entire_file_from_path(path, a)
		if rerr != nil { b.why = fmt.aprintf("%s cannot be read", path); return }
		v, err := json.parse(text, allocator = a)
		if err != nil { b.why = strings.clone("the options' index is not JSON"); return }
		all, _ := v.(json.Object)
		for k, o in all {
			if ro, _ := at_(o, "readOnly").(json.Boolean); ro { continue }
			append(&b.entries, Entry{key = k, name = str(at_(o, "type")), version = str(at(o, {"default", "text"})), description = str(at_(o, "description"))})
		}
	case .Zones:
		r := run({"timedatectl", "list-timezones"}, allocator = a)
		if !r.ok { b.why = strings.clone(strings.trim_space(r.stderr) != "" ? strings.trim_space(r.stderr) : "the time zones cannot be read"); return }
		now := time.now()
		for line in strings.split_lines(strings.trim_space(r.stdout), a) {
			if line == "" { continue }
			offset := zone_offset(line, now)
			words, _ := strings.replace_all(line, "_", " ", a)
			words, _ = strings.replace_all(words, "/", " ", a)
			o := offset_words(offset, a)
			append(&b.entries, Entry{key = line, name = o, description = fmt.aprintf("%s %s", words, o, allocator = a), offset = offset})
		}
	}
	slice.sort_by(b.entries[:], proc(x, y: Entry) -> bool { return x.key < y.key })
}

// The offset of zone `name` from UTC at `now`, in seconds (0: UTC, or a zone the tz database lacks).
zone_offset :: proc(name: string, now: time.Time) -> int {
	// (each zone's rules go with it: six hundred of them in one worker's temporary memory add up)
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	region, ok := timezone.region_load(name, context.temp_allocator)
	if !ok || region == nil { return 0 }
	// (the time there as a date without its zone, read back as a time: the gap to now is the offset)
	utc, uok := time.time_to_datetime(now)
	if !uok { return 0 }
	local, lok := timezone.datetime_to_tz(utc, region)
	if !lok { return 0 }
	local.tz = nil
	there, tok := time.datetime_to_time(local)
	if !tok { return 0 }
	// (now has its fraction of a second, the date read back has none)
	return int(math.round(time.duration_seconds(time.diff(now, there))))
}

// "UTC", "UTC+1", "UTC-3:30": whole hours without their minutes, so that "utc+9" finds Tokyo.
offset_words :: proc(seconds: int, allocator := context.temp_allocator) -> string {
	if seconds == 0 { return strings.clone("UTC", allocator) }
	s := abs(seconds)
	sign := seconds < 0 ? "-" : "+"
	if s % 3600 == 0 { return fmt.aprintf("UTC%s%d", sign, s / 3600, allocator = allocator) }
	return fmt.aprintf("UTC%s%d:%02d", sign, s / 3600, s % 3600 / 60, allocator = allocator)
}

at_ :: proc(v: json.Value, key: string) -> json.Value { return at(v, {key}) }

@(private = "file")
index_done :: proc(data: rawptr, _: u64) {
	b := (^Index_Build)(data)
	index := b.index
	if b.why != "" {
		index.state, index.why = .Failed, b.why
		virtual.arena_destroy(&b.arena)
	} else {
		virtual.arena_destroy(&index.arena)
		index.arena, index.entries, index.state = b.arena, b.entries, .Ready
		index.answered = -1   // (the query shown is searched again on this index)
	}
	free(b)
	host_settle(the_app)
}

@(private = "file")
index_lost :: proc(data: rawptr) { free(data) }

////////////////////////////////
// The search

@(private = "file")
Query :: struct {
	index:  ^Index,
	number: int,
	text:   string,
	hits:   [dynamic]Entry,
}

// Asks for the hits of `text` when it changed (or the index came): a search on a worker; its answer comes back numbered.
index_search :: proc(app: ^App, index: ^Index, text: string) {
	if index.state != .Ready { return }
	// (asked already, its answer shown or on its way; -1: the index came after the query, which is searched once more)
	if text == index.query && index.answered != -1 { return }
	delete(index.query)
	index.query = strings.clone(text)
	index.asked += 1
	if index.answered == -1 { index.answered = 0 }
	ui.task(&app.main.state, search_work, search_done, new_clone(Query{index = index, number = index.asked, text = strings.clone(text)}), search_lost)
}

@(private = "file")
search_work :: proc(data: rawptr) {
	q := (^Query)(data)
	words := strings.fields(strings.to_lower(q.text, context.temp_allocator), context.temp_allocator)
	if len(words) == 0 { return }
	first := make([dynamic]Entry)   // the name says it
	rest := make([dynamic]Entry)    // only the description does
	defer delete(first)
	defer delete(rest)
	for e in q.index.entries {
		in_key, in_all := true, true
		for w in words {
			k := contains_fold(e.key, w)
			in_key &&= k
			in_all &&= k || contains_fold(e.description, w)
		}
		if in_key { append(&first, e) } else if in_all && len(rest) < HITS_MAX { append(&rest, e) }
	}
	// (the shortest names first: "firefox" before "firefox-devedition-unwrapped")
	slice.sort_by(first[:], proc(x, y: Entry) -> bool { return len(x.key) < len(y.key) || (len(x.key) == len(y.key) && x.key < y.key) })
	q.hits = make([dynamic]Entry)
	for e in first { if len(q.hits) < HITS_MAX { append(&q.hits, e) } }
	for e in rest { if len(q.hits) < HITS_MAX { append(&q.hits, e) } }
}

// Whether `hay` holds `lower` (in lowercase), whatever the case of `hay`'s ASCII letters; no memory.
contains_fold :: proc(hay, lower: string) -> bool {
	n := len(lower)
	if n == 0 { return true }
	outer: for i := 0; i + n <= len(hay); i += 1 {
		for j in 0 ..< n {
			c := hay[i + j]
			if c >= 'A' && c <= 'Z' { c += 32 }
			if c != lower[j] { continue outer }
		}
		return true
	}
	return false
}

@(private = "file")
search_done :: proc(data: rawptr, _: u64) {
	q := (^Query)(data)
	index := q.index
	if q.number == index.asked {
		delete(index.hits)
		index.hits = q.hits
		index.answered = q.number
	} else {
		delete(q.hits)
	}
	delete(q.text)
	free(q)
	host_settle(the_app)
}

@(private = "file")
search_lost :: proc(data: rawptr) { free(data) }

index_destroy :: proc(index: ^Index) {
	virtual.arena_destroy(&index.arena)
	delete(index.hits)
	delete(index.query)
	delete(index.why)
}

////////////////////////////////
// An option's value, read when it is shown

@(private = "file")
Option_Read :: struct {
	app:          ^App,
	folder, host: string,
	path:         string,
	value:        string,
}

// The value of an option of the system, evaluated on a worker the first time the page shows it.
option_value :: proc(app: ^App, path: string) -> (text: string, known: bool) {
	if v, ok := app.option_values[path]; ok { return v, true }
	if app.source != .Folder || path in app.option_asked { return "", false }
	app.option_asked[strings.clone(path)] = true
	ui.task(&app.main.state, value_work, value_done, new_clone(Option_Read{app = app, folder = app.folder, host = app.host, path = strings.clone(path)}), value_lost)
	return "", false
}

@(private = "file")
value_work :: proc(data: rawptr) {
	o := (^Option_Read)(data)
	r := run({"nix", "eval", "--json", "--no-warn-dirty", fmt.tprintf("%s#nixosConfigurations.%s.config.%s", o.folder, o.host, o.path)})
	if r.ok {
		v := strings.trim_space(r.stdout)
		o.value = strings.clone(len(v) > 400 ? fmt.tprintf("%s…", v[:400]) : v)
	} else {
		o.value = strings.clone("(it cannot be evaluated)")
	}
	delete(r.stdout); delete(r.stderr)
}

@(private = "file")
value_done :: proc(data: rawptr, _: u64) {
	o := (^Option_Read)(data)
	o.app.option_values[o.path] = o.value
	free(o)
	host_settle(the_app)
}

@(private = "file")
value_lost :: proc(data: rawptr) { free(data) }
