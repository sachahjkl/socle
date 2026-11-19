package socletool

import "core:fmt"
import "core:os"
import cli "gt:cli"
import toolbox "gt:toolbox"

DEMO_OUT :: "src/demo/info.json"

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
	return .Done
}
