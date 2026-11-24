package socle

// What the window knows of the system, and the draft (src/md/features/apply.md, "The draft").
//
// - Info: one evaluation of the folder (lib.nix, socleInfo): the values that result, the template's values, the
//   facts of each page's options, the pages, the popular apps, the gallery. The demo is a kept evaluation of
//   tests/demo (src/demo/info.json), so the demo and a real system go through the same code.
// - The draft is the person's layer (socle/system.json) as a JSON tree; `committed` is the same file at the folder's
//   last commit. A value shown is the draft's when the draft sets it, else the evaluation's.

import "core:encoding/json"
import "core:fmt"
import "core:mem/virtual"
import "core:slice"
import "core:strings"

Popular :: struct {
	attr, name, about, category, version: string,
	unfree: bool,
}

Gallery_Entry :: struct {
	ref, title, description, parent, target: string,
	code: bool,   // it carries Nix of its own, which runs as root (templates.md, "Trust")
}

// Every template of socle's, of both targets (src/demo/gallery.json, written by `socletool demo` from the flake): the
// installer and the start of a home list them before any folder evaluates.
GALLERY :: #load("demo/gallery.json", string)

// socle's templates of `target`, in its title's order; their strings in `allocator` (gallery_destroy frees them).
templates_of :: proc(target: Target, allocator := context.allocator) -> [dynamic]Gallery_Entry {
	out := make([dynamic]Gallery_Entry, allocator)
	v, err := json.parse_string(GALLERY, allocator = context.temp_allocator)
	if err != nil { return out }
	want := target == .Home ? "home" : "system"
	for g in arr(v) {
		if str(at(g, {"target"})) != want { continue }
		append(&out, Gallery_Entry{
			ref = strings.clone(str(at(g, {"ref"})), allocator), title = strings.clone(str(at(g, {"title"})), allocator),
			description = strings.clone(str(at(g, {"description"})), allocator), parent = strings.clone(str(at(g, {"parent"})), allocator),
			target = strings.clone(want, allocator),
		})
	}
	return out
}

gallery_destroy :: proc(g: ^[dynamic]Gallery_Entry) {
	for e in g { delete(e.ref); delete(e.title); delete(e.description); delete(e.parent); delete(e.target) }
	delete(g^)
}

Page_Def :: struct {
	id, title, icon, group: string,
	order:   int,
	options: []string,
}

Fact :: struct {
	type, description: string,
	enums:             []string,
	value, default:    json.Value,
}

Info :: struct {
	arena:          virtual.Arena,
	effective:      json.Value,   // config.socle as it results
	template:       json.Value,   // the templates' values, merged
	facts:          map[string]Fact,
	pages:          [dynamic]Page_Def,
	popular:        [dynamic]Popular,
	gallery:        [dynamic]Gallery_Entry,
	template_title: string,
	release:        string,       // NixOS's release of the evaluated system
	nixpkgs:        string,       // the locked Nixpkgs's path in the store
	inputs:         map[string]i64,   // a flake input's name -> its lastModified
	ok:             bool,
}

// Reads an evaluation's JSON into a new Info. Everything it holds lives in its arena.
info_parse :: proc(text: string) -> (info: ^Info, why: string) {
	info = new(Info)
	if virtual.arena_init_growing(&info.arena) != nil { free(info); return nil, "no memory" }
	a := virtual.arena_allocator(&info.arena)
	v, err := json.parse_string(text, parse_integers = true, allocator = a)
	if err != nil {
		info_destroy(info)
		return nil, fmt.tprintf("the evaluation's answer is not JSON (%v)", err)
	}
	root, _ := v.(json.Object)
	info.effective = root["effective"]
	info.template = root["template"]
	info.release, _ = root["nixos"].(json.String)
	info.nixpkgs, _ = root["nixpkgs"].(json.String)
	info.facts = make(map[string]Fact, a)
	info.pages = make([dynamic]Page_Def, a)
	info.popular = make([dynamic]Popular, a)
	info.gallery = make([dynamic]Gallery_Entry, a)
	info.inputs = make(map[string]i64, a)
	if facts, ok := root["facts"].(json.Object); ok {
		for path, f in facts {
			o, _ := f.(json.Object)
			fact := Fact{type = str(o["type"]), description = str(o["description"]), value = o["value"], default = o["default"]}
			if enums, is := o["enums"].(json.Array); is {
				list := make([dynamic]string, a)
				for e in enums { append(&list, str(e)) }
				fact.enums = list[:]
			}
			info.facts[path] = fact
		}
	}
	if pages, ok := root["pages"].(json.Object); ok {
		for id, p in pages {
			o, _ := p.(json.Object)
			def := Page_Def{id = id, title = str(o["title"]), icon = str(o["icon"]), group = str(o["group"]), order = int(num(o["order"]))}
			if opts, is := o["options"].(json.Array); is {
				list := make([dynamic]string, a)
				for e in opts { append(&list, str(e)) }
				def.options = list[:]
			}
			append(&info.pages, def)
		}
		slice.sort_by(info.pages[:], proc(x, y: Page_Def) -> bool { return x.order < y.order })
	}
	for p in arr(root["popular"]) {
		o, _ := p.(json.Object)
		u, _ := o["unfree"].(json.Boolean)
		append(&info.popular, Popular{attr = str(o["attr"]), name = str(o["name"]), about = str(o["about"]), category = str(o["category"]), version = str(o["version"]), unfree = bool(u)})
	}
	for g in arr(root["gallery"]) {
		o, _ := g.(json.Object)
		code, _ := o["code"].(json.Boolean)
		append(&info.gallery, Gallery_Entry{ref = str(o["ref"]), title = str(o["title"]), description = str(o["description"]), parent = str(o["parent"]), target = str(o["target"]), code = bool(code)})
	}
	for t in arr(root["templates"]) {
		o, _ := t.(json.Object)
		info.template_title = str(o["title"])   // (the leaf: the last of the chain)
	}
	if inputs, ok := root["inputs"].(json.Object); ok {
		for name, i in inputs {
			o, _ := i.(json.Object)
			info.inputs[name] = i64(num(o["lastModified"]))
		}
	}
	info.ok = true
	return info, ""
}

info_destroy :: proc(info: ^Info) {
	if info == nil { return }
	virtual.arena_destroy(&info.arena)
	free(info)
}

str :: proc(v: json.Value) -> string {
	s, _ := v.(json.String)
	return string(s)
}

num :: proc(v: json.Value) -> f64 {
	#partial switch n in v {
	case json.Integer: return f64(n)
	case json.Float:   return f64(n)
	}
	return 0
}

arr :: proc(v: json.Value) -> json.Array {
	a, _ := v.(json.Array)
	return a
}

// The value at `path` under `v` (nil: none).
at :: proc(v: json.Value, path: []string) -> json.Value {
	cur := v
	for p in path {
		o, ok := cur.(json.Object)
		if !ok { return nil }
		next, has := o[p]
		if !has { return nil }
		cur = next
	}
	return cur
}

// A dotted path as its steps, in the temporary memory.
steps :: proc(path: string) -> []string { return strings.split(path, ".", context.temp_allocator) }

////////////////////////////////
// The draft

Layer :: struct {
	tree: json.Value,   // the whole file: {"socle": 1, "template": ..., "values": {...}}; owned, the heap's
}

layer_parse :: proc(text: string) -> Layer {
	v, err := json.parse_string(text, parse_integers = true)
	if err != nil || v == nil {
		o := make(json.Object)
		o[strings.clone("socle")] = json.Integer(1)
		o[strings.clone("values")] = make(json.Object)
		return {tree = o}
	}
	return {tree = v}
}

layer_destroy :: proc(l: ^Layer) {
	json.destroy_value(l.tree)
	l.tree = nil
}

layer_clone :: proc(l: Layer) -> Layer { return {tree = json.clone_value(l.tree)} }

// A JSON value's text, on one line ("null" for nil).
json_text :: proc(v: json.Value, allocator := context.allocator) -> string {
	if v == nil { return strings.clone("null", allocator) }
	data, _ := json.marshal(v, {sort_maps_by_key = true}, allocator)
	return string(data)
}

layer_text :: proc(l: Layer, allocator := context.allocator) -> string {
	data, _ := json.marshal(l.tree, {pretty = true, use_spaces = true, spaces = 2, sort_maps_by_key = true}, context.temp_allocator)
	// (the encoder writes an empty object as "{", a blank line and "}": a layer that sets nothing reads {})
	b := strings.builder_make(allocator)
	text := string(data)
	quoted := false   // (inside a string: its text stays as it is)
	for i := 0; i < len(text); i += 1 {
		switch {
		case quoted && text[i] == '\\' && i + 1 < len(text):
			strings.write_byte(&b, text[i]); i += 1; strings.write_byte(&b, text[i]); continue
		case text[i] == '"':
			quoted = !quoted
		}
		if !quoted && text[i] == '{' {
			j := i + 1
			for j < len(text) && (text[j] == '\n' || text[j] == ' ') { j += 1 }
			if j < len(text) && text[j] == '}' {
				strings.write_string(&b, "{}")
				i = j
				continue
			}
		}
		strings.write_byte(&b, text[i])
	}
	strings.write_byte(&b, '\n')
	return strings.to_string(b)
}

// The draft's value at a path under "values" (nil: the draft does not set it).
layer_get :: proc(l: Layer, path: []string) -> json.Value {
	return at(at(l.tree, {"values"}), path)
}

// Sets a value under "values", making the objects on the way. `v` becomes the layer's.
// (a map is a value: a map changed is written back into its parent at each level, or a growth is lost)
layer_set :: proc(l: ^Layer, path: []string, v: json.Value) {
	if len(path) == 0 { json.destroy_value(v); return }
	root, _ := l.tree.(json.Object)
	values: json.Object
	key, has := find_key(root, "values")
	if has {
		if o, is := root[key].(json.Object); is { values = o } else { json.destroy_value(root[key]); values = make(json.Object) }
	} else {
		key, values = strings.clone("values"), make(json.Object)
	}
	root[key] = put_in(values, path, v)
	l.tree = root
}

@(private = "file")
put_in :: proc(o: json.Object, path: []string, v: json.Value) -> json.Object {
	o := o
	key, has := find_key(o, path[0])
	if len(path) == 1 {
		if has { json.destroy_value(o[key]); o[key] = v } else { o[strings.clone(path[0])] = v }
		return o
	}
	child: json.Object
	if has {
		if c, is := o[key].(json.Object); is { child = c } else { json.destroy_value(o[key]); child = make(json.Object) }
	} else {
		key, child = strings.clone(path[0]), make(json.Object)
	}
	o[key] = put_in(child, path[1:], v)
	return o
}

// Removes a value under "values", and the objects it leaves empty: the template's or the system's value shows again.
layer_unset :: proc(l: ^Layer, path: []string) {
	root, ok := l.tree.(json.Object)
	if !ok || len(path) == 0 { return }
	key, has := find_key(root, "values")
	if !has { return }
	values, is := root[key].(json.Object)
	if !is { return }
	root[key] = remove_in(values, path)
	l.tree = root
}

@(private = "file")
remove_in :: proc(o: json.Object, path: []string) -> json.Object {
	o := o
	key, has := find_key(o, path[0])
	if !has { return o }
	if len(path) == 1 {
		json.destroy_value(o[key])
		delete_key(&o, key)
		delete(key)
		return o
	}
	if child, is := o[key].(json.Object); is {
		child = remove_in(child, path[1:])
		if len(child) == 0 {
			json.destroy_value(child)
			delete_key(&o, key)
			delete(key)
		} else {
			o[key] = child
		}
	}
	return o
}

// (the map's own key string: it is freed with the entry)
@(private = "file")
find_key :: proc(o: json.Object, name: string) -> (string, bool) {
	for k in o { if k == name { return k, true } }
	return "", false
}

layer_template :: proc(l: Layer) -> string { return str(at(l.tree, {"template"})) }

layer_set_template :: proc(l: ^Layer, ref: string) {
	root, _ := l.tree.(json.Object)
	if key, had := find_key(root, "template"); had {
		json.destroy_value(root[key])
		root[key] = json.String(strings.clone(ref))
	} else {
		root[strings.clone("template")] = json.String(strings.clone(ref))
	}
	l.tree = root
}

////////////////////////////////
// Values as the window shows them

// The value at a dotted path: the draft's, else the evaluation's (socle.* from `effective`, any other from the page
// facts).
value_at :: proc(app: ^App, path: string) -> json.Value {
	p := steps(path)
	// (the machine's layer wins over the person's: configuration.md, "The layers")
	if v := layer_get(app.machine, p); v != nil { return v }
	if v := layer_get(app.draft, p); v != nil { return v }
	if app.info == nil { return nil }
	if p[0] == "socle" { return at(app.info.effective, p[1:]) }
	if f, ok := app.info.facts[path]; ok { return f.value }
	return nil
}

bool_at :: proc(app: ^App, path: string) -> bool {
	b, _ := value_at(app, path).(json.Boolean)
	return bool(b)
}

text_at :: proc(app: ^App, path: string) -> string { return str(value_at(app, path)) }

// The template's value at a dotted path (nil: the template does not set it).
template_at :: proc(app: ^App, path: string) -> json.Value {
	if app.info == nil { return nil }
	return at(app.info.template, steps(path))
}

// Sets a value of the draft; a value equal to the template's is not kept (the template's shows again).
set_value :: proc(app: ^App, path: string, v: json.Value) {
	if t := template_at(app, path); t != nil && json_equal(t, v) {
		layer_unset(&app.draft, steps(path))
		json.destroy_value(v)
	} else {
		layer_set(&app.draft, steps(path), v)
	}
	draft_changed(app)
}

set_bool :: proc(app: ^App, path: string, b: bool) { set_value(app, path, json.Boolean(b)) }
set_text :: proc(app: ^App, path: string, s: string) { set_value(app, path, json.String(strings.clone(s))) }

reset_value :: proc(app: ^App, path: string) {
	layer_unset(&app.draft, steps(path))
	draft_changed(app)
}

// Whether the draft sets a path (a value of the person, "changed by you").
draft_sets :: proc(app: ^App, path: string) -> bool { return layer_get(app.draft, steps(path)) != nil }

json_equal :: proc(a, b: json.Value) -> bool {
	#partial switch x in a {
	case json.Null:    _, ok := b.(json.Null); return ok
	case json.Boolean: y, ok := b.(json.Boolean); return ok && x == y
	case json.String:  y, ok := b.(json.String); return ok && x == y
	case json.Integer:
		#partial switch y in b {
		case json.Integer: return x == y
		case json.Float:   return f64(x) == f64(y)
		}
		return false
	case json.Float:   return num(b) == f64(x)
	case json.Array:
		y, ok := b.(json.Array)
		if !ok || len(x) != len(y) { return false }
		for e, i in x { if !json_equal(e, y[i]) { return false } }
		return true
	case json.Object:
		y, ok := b.(json.Object)
		if !ok || len(x) != len(y) { return false }
		for k, e in x {
			f, has := y[k]
			if !has || !json_equal(e, f) { return false }
		}
		return true
	}
	return a == nil && b == nil
}

// The apps as they result: the evaluation's set, then the draft's own entries over it.
app_on :: proc(app: ^App, attr: string) -> bool {
	if v := layer_get(app.draft, {"socle", "packages", attr}); v != nil { b, _ := v.(json.Boolean); return bool(b) }
	if app.info == nil { return false }
	b, _ := at(app.info.effective, {"packages", attr}).(json.Boolean)
	return bool(b)
}

// Whether the template adds an app.
app_from_template :: proc(app: ^App, attr: string) -> bool {
	b, _ := template_at(app, fmt.tprintf("socle.packages.%s", attr)).(json.Boolean)
	return bool(b)
}

set_app :: proc(app: ^App, p: Popular, on: bool) {
	path := fmt.tprintf("socle.packages.%s", p.attr)
	// (an app's own entry goes when it says what the template says; an app no layer below adds, removed, goes too)
	below := app_from_template(app, p.attr)
	if on == below { layer_unset(&app.draft, steps(path)) } else { layer_set(&app.draft, steps(path), json.Boolean(on)) }
	if p.unfree {
		u := fmt.tprintf("socle.unfree.%s", p.attr)
		if on { layer_set(&app.draft, steps(u), json.Boolean(true)) } else { layer_unset(&app.draft, steps(u)) }
	}
	draft_changed(app)
}

////////////////////////////////
// The changes in words

Change :: struct {
	page:    string,
	text:    string,
	restart: bool,   // the session restarts when it applies
}

// The changes of the draft against the committed layer, made again at each change of the draft (never in a frame).
changes_update :: proc(app: ^App) {
	for c in app.changes { delete(c.text); delete(c.page) }
	clear(&app.changes)
	if layer_template(app.draft) != layer_template(app.committed) {
		append(&app.changes, Change{strings.clone("Templates"), fmt.aprintf("Start from %s", gallery_title(app, layer_template(app.draft))), true})
	}
	leaves := make([dynamic]string, context.temp_allocator)
	collect_leaves(at(app.draft.tree, {"values"}), "", &leaves)
	collect_leaves(at(app.committed.tree, {"values"}), "", &leaves)
	slice.sort(leaves[:])
	last := ""
	for path in leaves {
		if path == last { continue }
		last = path
		p := steps(path)
		now, was := layer_get(app.draft, p), layer_get(app.committed, p)
		if now != nil && was != nil && json_equal(now, was) { continue }
		if strings.has_prefix(path, "socle.unfree.") { continue }   // (said with its app)
		// (a session that opens by itself, and whose: one change in words)
		if path == "socle.desktop.autoLogin.enable" && now != nil && bool_of(now) && layer_get(app.draft, {"socle", "desktop", "autoLogin", "user"}) != nil { continue }
		page, text, restart := change_words(app, path, now)
		append(&app.changes, Change{strings.clone(page), text, restart})
	}
	// the update of a source: a newer lock than the committed one
	for name, t in app.lock_now {
		if was, ok := app.lock_committed[name]; ok && was != t {
			append(&app.changes, Change{strings.clone("Updates"), fmt.aprintf("%s of %s", input_title(name), date_words(t)), false})
		}
	}
}

@(private = "file")
collect_leaves :: proc(v: json.Value, prefix: string, out: ^[dynamic]string) {
	o, ok := v.(json.Object)
	if !ok {
		if prefix != "" { append(out, prefix) }
		return
	}
	for k, child in o {
		collect_leaves(child, prefix == "" ? k : fmt.tprintf("%s.%s", prefix, k), out)
	}
}

// A change in the person's words: the page it belongs to and what it does (`now` nil: the person's value goes, the
// template's or the system's comes back).
change_words :: proc(app: ^App, path: string, now: json.Value) -> (page: string, text: string, restart: bool) {
	shown := now != nil ? now : value_at(app, path)
	switch {
	case strings.has_prefix(path, "socle.packages."):
		attr := path[len("socle.packages."):]
		name := app_name(app, attr)
		on := app_on(app, attr)
		if now == nil { return "Apps", fmt.aprintf("%s as the template has it", name), false }
		if on { return "Apps", fmt.aprintf("Add %s for everyone", name), false }
		if app_from_template(app, attr) { return "Apps", fmt.aprintf("Remove %s, which the template adds", name), false }
		return "Apps", fmt.aprintf("Remove %s", name), false
	case path == "socle.desktop.environment":
		return "Desktop", fmt.aprintf("Environment: %s", desktop_title(str(shown))), true
	case path == "socle.desktop.dark":
		return "Desktop", strings.clone(bool_of(shown) ? "Dark look" : "Light look"), false
	case path == "socle.desktop.autoLogin.enable":
		return "Desktop", strings.clone(bool_of(shown) ? "Log in by itself" : "Ask every person's password at start"), false
	case path == "socle.desktop.autoLogin.user":
		return "Desktop", fmt.aprintf("Log in by itself as %s", person_title(app, str(shown))), false
	case path == "socle.desktop.lockAfter":
		return "Desktop", fmt.aprintf("Lock the screen: %s", lock_title(int(num(shown)))), false
	case path == ZONE_PATH:
		return "Region", fmt.aprintf("Time zone: %s", str(shown)), false
	case path == LOCALE_PATH:
		name := str(shown)
		for l in LANGUAGES { if l.locale == name { name = l.title } }
		return "Region", fmt.aprintf("Language: %s", name), false
	case path == KEYBOARD_PATH:
		name := str(shown)
		for k in KEYBOARDS { if k[1] == name { name = k[0] } }
		return "Region", fmt.aprintf("Keyboard: %s", name), false
	case strings.has_prefix(path, "socle.people."):
		rest := path[len("socle.people."):]
		login := rest[:strings.index_byte(rest, '.') if strings.index_byte(rest, '.') >= 0 else len(rest)]
		if strings.has_suffix(path, ".admin") {
			return "People", fmt.aprintf(bool_of(shown) ? "%s administers the machine" : "%s no longer administers the machine", person_title(app, login)), false
		}
		return "People", fmt.aprintf("%s: %s", person_title(app, login), value_words(shown)), false
	}
	page = "All settings"
	if app.info != nil {
		for p in app.info.pages {
			for o in p.options { if o == path { page = p.title } }
		}
	}
	return page, fmt.aprintf("%s: %s", option_title(app, path), value_words(shown)), false
}

bool_of :: proc(v: json.Value) -> bool { b, _ := v.(json.Boolean); return bool(b) }

value_words :: proc(v: json.Value) -> string {
	#partial switch x in v {
	case json.Boolean: return x ? "on" : "off"
	case json.String:  return string(x)
	case json.Integer: return fmt.tprintf("%d", x)
	case json.Float:   return fmt.tprintf("%g", x)
	case nil:          return "as the system decides"
	}
	return "set"
}

// An option's words: the first sentence of its description, or its path.
option_title :: proc(app: ^App, path: string) -> string {
	if app.info != nil {
		if f, ok := app.info.facts[path]; ok && f.description != "" { return description_title(f.description) }
	}
	return path
}

// "Whether to enable support for Bluetooth." -> "Support for Bluetooth".
description_title :: proc(d: string) -> string {
	s := strings.trim_space(d)
	if dot := strings.index_any(s, ".\n"); dot > 0 { s = s[:dot] }
	for prefix in ([]string{"Whether to enable ", "Whether to use ", "Whether to run ", "Whether to allow ", "Whether to ", "Whether ", "Enable ", "Whether the "}) {
		if strings.has_prefix(s, prefix) { s = s[len(prefix):]; break }
	}
	// (a title, not a paragraph: what comes after a comma or a parenthesis is the description's)
	if len(s) > 48 {
		if cut := strings.index_any(s, ",("); cut > 12 { s = strings.trim_space(s[:cut]) }
	}
	if len(s) > 0 && s[0] >= 'a' && s[0] <= 'z' {
		return fmt.tprintf("%c%s", s[0] - 32, s[1:])
	}
	return s
}

desktop_title :: proc(id: string) -> string {
	switch id {
	case "plasma": return "Plasma"
	case "gnome":  return "GNOME"
	case "cosmic": return "COSMIC"
	case "none":   return "None"
	}
	return id
}

// "never", "after 5 min", "after 1 h 30 min": a delay of the screen lock, in minutes.
lock_title :: proc(minutes: int) -> string {
	if minutes <= 0 { return "never" }
	if minutes < 60 { return fmt.tprintf("after %d min", minutes) }
	if minutes % 60 == 0 { return fmt.tprintf("after %d h", minutes / 60) }
	return fmt.tprintf("after %d h %02d min", minutes / 60, minutes % 60)
}

app_name :: proc(app: ^App, attr: string) -> string {
	if app.info != nil {
		for p in app.info.popular { if p.attr == attr { return p.name } }
	}
	return attr
}

person_title :: proc(app: ^App, login: string) -> string {
	d := text_at(app, fmt.tprintf("socle.people.%s.description", login))
	return d != "" ? d : login
}

gallery_title :: proc(app: ^App, ref: string) -> string {
	if app.info != nil {
		for g in app.info.gallery { if g.ref == ref { return g.title } }
	}
	return ref
}

input_title :: proc(name: string) -> string {
	switch name {
	case "nixpkgs": return "Software catalogue"
	case "socle":   return "socle"
	}
	return name
}

changes_restart :: proc(app: ^App) -> bool {
	for c in app.changes { if c.restart { return true } }
	return false
}
