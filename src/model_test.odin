package socle

import "core:encoding/json"
import "core:strings"
import "core:testing"

@(test)
layer_sets_deep_values_and_keeps_them :: proc(t: ^testing.T) {
	l := layer_parse(`{"socle": 1, "values": {"socle": {"people": {"ada": {"admin": true}}}}}`)
	defer layer_destroy(&l)
	// (many keys at one level: the map grows, and the growth must reach the parent)
	for name in ([]string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r"}) {
		layer_set(&l, {"socle", "packages", name}, json.Boolean(true))
	}
	layer_set(&l, {"services", "printing", "enable"}, json.Boolean(false))
	testing.expect(t, bool_of(layer_get(l, {"socle", "packages", "r"})))
	testing.expect(t, bool_of(layer_get(l, {"socle", "people", "ada", "admin"})))
	testing.expect(t, layer_get(l, {"services", "printing", "enable"}) != nil)
	text := layer_text(l, context.temp_allocator)
	testing.expect(t, strings.contains(text, `"printing"`))
}

@(test)
layer_unset_removes_the_objects_it_empties :: proc(t: ^testing.T) {
	l := layer_parse(`{"socle": 1, "values": {"socle": {"desktop": {"environment": "plasma"}, "dark": true}}}`)
	defer layer_destroy(&l)
	layer_unset(&l, {"socle", "desktop", "environment"})
	testing.expect(t, layer_get(l, {"socle", "desktop"}) == nil)
	testing.expect(t, bool_of(layer_get(l, {"socle", "dark"})))
	layer_unset(&l, {"socle", "dark"})
	testing.expect(t, layer_get(l, {"socle"}) == nil)
	layer_unset(&l, {"nothing", "here"})
}

@(test)
layers_compare_by_value :: proc(t: ^testing.T) {
	a := layer_parse(`{"values": {"x": {"y": [1, 2, "z"]}}}`)
	b := layer_parse(`{"values": {"x": {"y": [1, 2, "z"]}}}`)
	defer layer_destroy(&a)
	defer layer_destroy(&b)
	testing.expect(t, json_equal(a.tree, b.tree))
	layer_set(&b, {"x", "w"}, json.Integer(3))
	testing.expect(t, !json_equal(a.tree, b.tree))
}

@(test)
descriptions_become_titles :: proc(t: ^testing.T) {
	testing.expect_value(t, description_title("Whether to enable support for Bluetooth."), "Support for Bluetooth")
	testing.expect_value(t, description_title("Enable support for SANE scanners.\n\nmore"), "Support for SANE scanners")
}

@(test)
the_layers_hash_is_the_librarys :: proc(t: ^testing.T) {
	// (lib.nix: builtins.hashString "sha256" (system + host); here "" + "": the hash of nothing)
	testing.expect_value(t, layers_hash("", ""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
}
