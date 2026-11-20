package socle

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

// The applied layer of a family's system: a template of socle's, an app, a setting, people and an account.
@(private = "file")
COMMITTED :: `{"socle": 1, "template": "socle#family-desktop", "values": {
  "services": {"printing": {"enable": false}},
  "socle": {"packages": {"krita": true}, "people": {"ada": {"admin": true, "description": "Ada"}}},
  "users": {"users": {"ada": {"initialPassword": "secret"}}}
}}`

@(private = "file")
FIXTURE :: "tests/template"

@(private = "file")
export_of_committed :: proc() -> Template_Export {
	committed := layer_parse(COMMITTED)
	values, parent := export_of(committed, nil)
	return {name = "my-desktop", title = "My desktop", description = "The family's desktop, with Krita and no printer.", target = .System, parent = parent, values = values}
}

// The export writes tests/template to the byte: the folder that the Nix check `exported` starts a system from.
// SOCLE_WRITE_FIXTURE=1 writes it again (then read its diff).
@(test)
export_writes_the_template_that_a_configuration_starts_from :: proc(t: ^testing.T) {
	tmp := os.get_env("TMPDIR", context.temp_allocator)
	dir := fmt.tprintf("%s/socle-export-test-%d", tmp != "" ? tmp : "/tmp", os.get_pid())
	defer os.remove_all(dir)
	why := template_export(dir, export_of_committed())
	testing.expectf(t, why == "", "template_export: %s", why)
	for f in ([]string{"flake.nix", "template.json", "layer.json", "README.md"}) {
		got := read_text(join(dir, f), context.temp_allocator)
		if os.get_env("SOCLE_WRITE_FIXTURE", context.temp_allocator) == "1" {
			_ = os.make_directory_all(FIXTURE)
			_ = os.write_entire_file(join(FIXTURE, f), got)
			continue
		}
		testing.expectf(t, got == read_text(join(FIXTURE, f), context.temp_allocator), "%s differs from %s", f, FIXTURE)
	}
	layer := read_text(join(dir, "layer.json"), context.temp_allocator)
	testing.expect(t, !strings.contains(layer, "people") && !strings.contains(layer, "secret"), "a template carries no accounts")
	testing.expect(t, strings.contains(layer, "krita"), "the person's apps go with it")
	testing.expect(t, template_export(dir, export_of_committed()) != "", "a folder that exists is never written over")
}

@(test)
export_flattens_a_parent_that_is_not_socles :: proc(t: ^testing.T) {
	committed := layer_parse(`{"socle": 1, "template": "template-mine#base", "values": {"socle": {"packages": {"krita": true}}}}`)
	defer layer_destroy(&committed)
	chain, _ := json.parse_string(`{"socle": {"packages": {"gimp": true, "krita": false}}}`, allocator = context.temp_allocator)
	values, parent := export_of(committed, chain)
	testing.expect_value(t, parent, "")
	testing.expect(t, bool_of(at(values, {"socle", "packages", "gimp"})), "the parent's values are in the layer")
	testing.expect(t, bool_of(at(values, {"socle", "packages", "krita"})), "the person's values win")
}

@(test)
export_leaves_no_empty_object :: proc(t: ^testing.T) {
	committed := layer_parse(`{"socle": 1, "template": "socle#minimal", "values": {"socle": {"people": {"ada": {"admin": true}}}}}`)
	defer layer_destroy(&committed)
	values, _ := export_of(committed, nil)
	o, _ := values.(json.Object)
	testing.expect_value(t, len(o), 0)
	tree := make(json.Object, context.temp_allocator)
	tree["socle"] = json.Integer(1)
	tree["values"] = values
	testing.expect_value(t, layer_text(Layer{tree = tree}, context.temp_allocator), "{\n  \"socle\": 1,\n  \"values\": {}\n}\n")
	// (a text that holds braces keeps them)
	tree["values"] = json.String(`a { } "and" b`)
	testing.expect(t, strings.contains(layer_text(Layer{tree = tree}, context.temp_allocator), `"a { } \"and\" b"`))
}

@(test)
a_template_link_is_checked_and_becomes_an_input :: proc(t: ^testing.T) {
	url, name, why := template_link("github:ada/desktops#my-desktop")
	testing.expect_value(t, why, "")
	testing.expect_value(t, url, "github:ada/desktops")
	testing.expect_value(t, name, "my-desktop")
	_, _, why = template_link("github:ada/desktops")
	testing.expect(t, why != "", "a link names its template")
	_, _, why = template_link("ftp://x#y")
	testing.expect(t, why != "", "a link is a flake's address")
	inputs := []Input{{"nixpkgs", NIXPKGS_URL}, {"socle", SOCLE_URL}, {template_input("my-desktop"), "github:ada/desktops"}}
	flake := flake_text(inputs, context.temp_allocator)
	testing.expect(t, strings.contains(flake, `template-my-desktop.url = "github:ada/desktops";`))
	// (a new folder's flake: its two inputs, socle's Nixpkgs followed)
	testing.expect(t, strings.contains(flake_text(inputs[:2], context.temp_allocator), `inputs.nixpkgs.follows = "nixpkgs";`))
	testing.expect_value(t, template_name("My Desktop, 2026!"), "my-desktop-2026")
}
