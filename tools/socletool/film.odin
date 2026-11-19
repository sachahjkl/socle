package socletool

import "core:fmt"
import cli "gt:cli"
import toolbox "gt:toolbox"

// `film [out.mp4]`: tools/socle_film built (optimised, the toolkit's native library first), then run from the
// checkout. It needs ffmpeg on the PATH; NVENC when the machine has it.
film_run :: proc(args: []string) -> cli.Exit {
	p := project()
	if !toolbox.build_native(p) { return toolbox.done("the toolkit's native library cannot be built") }
	exe := "build/socle_film"
	if !toolbox.run(toolbox.odin_command(p, "build", "tools/socle_film", {fmt.tprintf("-out:%s", exe), "-o:speed"}, release = true), {echo = true}) {
		return toolbox.done("building tools/socle_film failed")
	}
	command := make([dynamic]string, context.temp_allocator)
	append(&command, exe)
	append(&command, ..args)
	return toolbox.run(command[:]) ? .Done : toolbox.done("the film failed")
}
