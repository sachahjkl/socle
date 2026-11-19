package socletool

import "core:fmt"
import "core:os"
import cli "gt:cli"
import toolbox "gt:toolbox"

DEMO_OUT :: "src/demo/info.json"
DEMO_LAYER_OUT :: "src/demo/system.json"
GALLERY_OUT :: "src/demo/gallery.json"

// `demo`: src/demo/info.json, the evaluation of tests/demo that the window shows with --demo (the pictures, the film,
// the tests). An evaluation kept, so the demo needs no nix and gives the same pictures each time.
demo_run :: proc(args: []string) -> cli.Exit {
	expr := `let f = builtins.getFlake (toString ./.); in (f.lib.configuration { inputs = f.inputs // { self = f; }; root = ./tests/demo; }).socleInfo.house-laptop`
	env, _ := os.environ(context.temp_allocator)
	state, out, errs, err := os.process_exec({command = {"nix", "eval", "--json", "--impure", "--no-warn-dirty", "--expr", expr}, env = env}, context.temp_allocator)
	if err != nil || !state.exited || state.exit_code != 0 {
		fmt.eprint(string(errs))
		return toolbox.done("nix eval of tests/demo failed (its files must be known to git)")
	}
	_ = os.make_directory_all("src/demo")
	if os.write_entire_file(DEMO_OUT, out) != nil { return toolbox.done(fmt.tprintf("%s cannot be written", DEMO_OUT)) }
	fmt.printfln("wrote %s", DEMO_OUT)
	// (its layer beside it: the program embeds both, and its package has no tests/ folder)
	layer, rerr := os.read_entire_file_from_path("tests/demo/socle/system.json", context.temp_allocator)
	if rerr != nil || os.write_entire_file(DEMO_LAYER_OUT, layer) != nil { return toolbox.done(fmt.tprintf("%s cannot be written", DEMO_LAYER_OUT)) }
	fmt.printfln("wrote %s", DEMO_LAYER_OUT)
	machine, merr := os.read_entire_file_from_path("tests/demo/socle/hosts/house-laptop.json", context.temp_allocator)
	if merr != nil || os.write_entire_file("src/demo/host.json", machine) != nil { return toolbox.done("src/demo/host.json cannot be written") }
	fmt.println("wrote src/demo/host.json")
	// (every template, of both targets: the installer and the start of a home list them before any folder evaluates)
	gallery := `let f = builtins.getFlake (toString ./.); in builtins.attrValues (builtins.mapAttrs (n: t: { ref = "socle#${n}"; inherit (t) title description target; parent = t.parent or null; }) f.socleTemplates)`
	gs, gout, gerrs, gerr := os.process_exec({command = {"nix", "eval", "--json", "--impure", "--no-warn-dirty", "--expr", gallery}, env = env}, context.temp_allocator)
	if gerr != nil || !gs.exited || gs.exit_code != 0 {
		fmt.eprint(string(gerrs))
		return toolbox.done("nix eval of the templates failed")
	}
	if os.write_entire_file(GALLERY_OUT, gout) != nil { return toolbox.done(fmt.tprintf("%s cannot be written", GALLERY_OUT)) }
	fmt.printfln("wrote %s", GALLERY_OUT)
	return .Done
}
