package socle

// Templates of a person's own (src/md/data/templates.md): the folder's flake written from data (socle/inputs.json),
// a template added from a link, and the applied system saved as a template of its own.

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

// An input of a folder's flake: its name and its address.
Input :: struct { name, url: string }

INPUTS_FILE :: "inputs.json"   // in socle/

// The flake of a folder that socle manages: its inputs (nixpkgs and socle first, then the templates' in their names'
// order) and one call to socle's library (configuration.md).
flake_text :: proc(inputs: []Input, allocator := context.allocator) -> string {
	b := strings.builder_make(allocator)
	strings.write_string(&b, "{\n  description = \"This machine's system, managed by socle: socle/*.json are its settings, custom/*.nix its code.\";\n  inputs = {\n")
	for i in inputs {
		switch i.name {
		case "nixpkgs":
			fmt.sbprintf(&b, "    nixpkgs.url = %q;\n", i.url)
		case "socle":
			fmt.sbprintf(&b, "    socle = {{\n      url = %q;\n      inputs.nixpkgs.follows = \"nixpkgs\";\n    }};\n", i.url)
		case:
			// (a template's flake has no inputs of its own: nothing to follow)
			fmt.sbprintf(&b, "    %s.url = %q;\n", i.name, i.url)
		}
	}
	strings.write_string(&b, "  };\n  outputs = inputs: inputs.socle.lib.configuration {\n    inherit inputs;\n    root = ./.;\n  };\n}\n")
	return strings.to_string(b)
}

// A new folder's inputs: socle's Nixpkgs and socle.
inputs_default :: proc(nixpkgs, socle: string) -> []Input {
	out := make([]Input, 2, context.temp_allocator)
	out[0] = {"nixpkgs", nixpkgs != "" ? nixpkgs : NIXPKGS_URL}
	out[1] = {"socle", socle != "" ? socle : SOCLE_URL}
	return out
}

// The text of socle/inputs.json for `inputs`.
inputs_text :: proc(inputs: []Input, allocator := context.allocator) -> string {
	o := make(json.Object, context.temp_allocator)
	for i in inputs { o[i.name] = json.String(i.url) }
	data, _ := json.marshal(o, {pretty = true, use_spaces = true, spaces = 2, sort_maps_by_key = true}, context.temp_allocator)
	return strings.concatenate({string(data), "\n"}, allocator)
}

// A folder's inputs, from socle/inputs.json, else from its flake.lock's addresses (a folder made before inputs.json):
// nixpkgs and socle first. In the temporary memory.
inputs_read :: proc(folder: string) -> []Input {
	out := make([dynamic]Input, context.temp_allocator)
	text := read_text(join(folder, "socle", INPUTS_FILE), context.temp_allocator)
	if text != "" {
		v, err := json.parse_string(text, allocator = context.temp_allocator)
		if o, ok := v.(json.Object); err == nil && ok { for k, u in o { append(&out, Input{k, str(u)}) } }
	} else {
		lock, err := json.parse_string(read_text(join(folder, "flake.lock"), context.temp_allocator), allocator = context.temp_allocator)
		if err == nil {
			roots, _ := at(lock, {"nodes", "root", "inputs"}).(json.Object)
			for name, key in roots {
				node := str(key)
				if node == "" { continue }
				if url := lock_url(at(lock, {"nodes", node, "original"})); url != "" { append(&out, Input{name, url}) }
			}
		}
	}
	rank :: proc(n: string) -> int { return n == "nixpkgs" ? 0 : n == "socle" ? 1 : 2 }
	slice.sort_by(out[:], proc(a, b: Input) -> bool {
		if rank(a.name) != rank(b.name) { return rank(a.name) < rank(b.name) }
		return a.name < b.name
	})
	return out[:]
}

// An input's address from its lock's "original" (the forms socle writes).
@(private = "file")
lock_url :: proc(o: json.Value) -> string {
	switch str(at(o, {"type"})) {
	case "tarball", "file": return str(at(o, {"url"}))
	case "path":            return fmt.tprintf("path:%s", str(at(o, {"path"})))
	case "github", "gitlab":
		ref := str(at(o, {"ref"}))
		return fmt.tprintf("%s:%s/%s%s", str(at(o, {"type"})), str(at(o, {"owner"})), str(at(o, {"repo"})), ref != "" ? fmt.tprintf("/%s", ref) : "")
	case "git":
		url := str(at(o, {"url"}))
		if b, ok := at(o, {"submodules"}).(json.Boolean); ok && bool(b) { url = fmt.tprintf("%s%ssubmodules=1", url, strings.contains(url, "?") ? "&" : "?") }
		return fmt.tprintf("git+%s", url)
	}
	return ""
}

// A link to a template: <flake reference>#<name>. Its parts, or why it is not one.
template_link :: proc(link: string) -> (url, name, why: string) {
	text := strings.trim_space(link)
	hash := strings.last_index_byte(text, '#')
	if hash <= 0 || hash == len(text) - 1 { return "", "", "A link ends with # and the template's name: github:owner/repo#name." }
	url, name = text[:hash], text[hash + 1:]
	for c in transmute([]u8)name {
		if !((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_') { return "", "", "A template's name takes lowercase letters, digits, - and _." }
	}
	ok := false
	for scheme in ([]string{"github:", "gitlab:", "git+https:", "git+ssh:", "git+file:", "path:", "https:"}) { ok ||= strings.has_prefix(url, scheme) }
	if !ok { return "", "", "The link's address is a flake's: github:, gitlab:, git+https:, git+file:, path: or https:." }
	return url, name, ""
}

// The input's name for a template's flake: from the template's name, as Nix names an input.
template_input :: proc(name: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, "template-")
	for c in transmute([]u8)name { strings.write_byte(&b, c == '_' ? '-' : c) }
	return strings.to_string(b)
}

// The template at `link` made an input of `folder`: socle/inputs.json and flake.nix written again. The reference the
// person's layer names, or why it failed.
template_add :: proc(folder, link: string) -> (ref, why: string) {
	url, name, bad := template_link(link)
	if bad != "" { return "", bad }
	input := template_input(name)
	inputs := make([dynamic]Input, context.temp_allocator)
	for i in inputs_read(folder) { if i.name != input { append(&inputs, i) } }
	if len(inputs) < 2 { return "", "The folder's inputs cannot be read: socle/inputs.json or flake.lock." }
	append(&inputs, Input{input, url})
	if os.write_entire_file(join(folder, "socle", INPUTS_FILE), inputs_text(inputs[:], context.temp_allocator)) != nil ||
	   os.write_entire_file(join(folder, "flake.nix"), flake_text(inputs[:], context.temp_allocator)) != nil {
		return "", "The folder's flake cannot be written."
	}
	return fmt.tprintf("%s#%s", input, name), ""
}

////////////////////////////////
// Save as a template

Template_Export :: struct {
	name, title, description: string,
	target: Target,
	parent: string,      // a template of socle's ("": none)
	values: json.Value,  // the layer's values: the person's, without people or accounts
}

// The applied system's layer as a template's (templates.md, "Save as template"): `committed`'s values without
// socle.people and users; a parent of socle's kept, any other flattened under them from `template` (the chain's
// values merged). The values in the temporary memory.
export_of :: proc(committed: Layer, template: json.Value) -> (values: json.Value, parent: string) {
	mine := json.clone_value(at(committed.tree, {"values"}), context.temp_allocator)
	o, ok := mine.(json.Object)
	if !ok { o = make(json.Object, context.temp_allocator) }
	delete_key(&o, "users")
	if s, is := o["socle"].(json.Object); is {
		s := s
		delete_key(&s, "people")
		o["socle"] = s
	}
	parent = layer_template(committed)
	if parent != "" && !strings.has_prefix(parent, "socle#") {
		base := json.clone_value(template, context.temp_allocator)
		return json_prune(json_merge(base, o)), ""
	}
	return json_prune(o), parent
}

// `v` without the objects left empty (socle with no more people in it): a layer says only what it sets.
json_prune :: proc(v: json.Value) -> json.Value {
	o, ok := v.(json.Object)
	if !ok { return v }
	empty := make([dynamic]string, context.temp_allocator)
	for k, x in o {
		o[k] = json_prune(x)
		if c, is := o[k].(json.Object); is && len(c) == 0 { append(&empty, k) }
	}
	for k in empty { delete_key(&o, k) }
	return o
}

// `over` merged over `base`, object by object; the result reuses both (temporary memory).
json_merge :: proc(base, over: json.Value) -> json.Value {
	b, bo := base.(json.Object)
	v, vo := over.(json.Object)
	if !bo || !vo { return over }
	for k, x in v { b[k] = k in b ? json_merge(b[k], x) : x }
	return b
}

// The template written in `dir` (a new git repository). "" or what went wrong.
template_export :: proc(dir: string, e: Template_Export) -> string {
	if os.exists(dir) { return fmt.tprintf("%s exists already", dir) }
	if os.make_directory_all(dir) != nil { return fmt.tprintf("%s cannot be made", dir) }
	meta := make(json.Object, context.temp_allocator)
	meta["title"] = json.String(e.title)
	meta["description"] = json.String(e.description)
	meta["target"] = json.String(e.target == .Home ? "home" : "system")
	meta["parent"] = e.parent != "" ? json.Value(json.String(e.parent)) : json.Value(json.Null{})
	meta_data, _ := json.marshal(meta, {pretty = true, use_spaces = true, spaces = 2, sort_maps_by_key = true}, context.temp_allocator)
	tree := make(json.Object, context.temp_allocator)
	tree["socle"] = json.Integer(1)
	tree["values"] = e.values
	layer := Layer{tree = tree}
	writes := [][2]string{
		{join(dir, "flake.nix"), fmt.tprintf(TEMPLATE_FLAKE, e.name, e.name)},
		{join(dir, "template.json"), strings.concatenate({string(meta_data), "\n"}, context.temp_allocator)},
		{join(dir, "layer.json"), layer_text(layer, context.temp_allocator)},
		{join(dir, "README.md"), fmt.tprintf(TEMPLATE_README, e.title, e.description, e.name)},
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
	if !(git(dir, "init", "-q") && git(dir, "add", "-A") && git(dir, "-c", "user.name=socle", "-c", "user.email=socle@localhost", "-c", "commit.gpgsign=false", "commit", "-q", "-m", fmt.tprintf("%s, saved by socle", e.title))) {
		return "git could not record the template"
	}
	return ""
}

// A template's name from its title: lowercase letters and digits, dashes between the words.
template_name :: proc(title: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	dash := false
	for r in strings.to_lower(title, context.temp_allocator) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			if dash && strings.builder_len(b) > 0 { strings.write_byte(&b, '-') }
			strings.write_rune(&b, r)
			dash = false
		} else {
			dash = true
		}
	}
	return strings.to_string(b)
}

TEMPLATE_FLAKE :: `# A template of socle's (https://socle.froment.software): its values in layer.json, what it is in template.json.
# Start from it in socle's Templates with this repository's address and "#%s".
{{
  outputs = _: {{
    socleTemplates."%s" = builtins.fromJSON (builtins.readFile ./template.json) // {{layer = ./layer.json;}};
  }};
}}
`

TEMPLATE_README :: `# %s

%s

A template of [socle](https://socle.froment.software), saved from a system that socle manages. To start a machine
from it: push this folder to a git host, then in socle's Templates, use the link
` + "`github:<owner>/<repository>#%s`" + `.
`
