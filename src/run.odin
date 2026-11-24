package socle

// Other programs (git, nix, pkexec), run on a worker, never on the interface's thread. Every child starts through
// gt:process, which holds the toolkit's one start lock: a start from socle and one from the toolkit never overlap.

import "core:bufio"
import "core:os"
import "core:path/filepath"
import "core:strings"
import process "gt:process"

// A path of `parts`, in the temporary memory.
join :: proc(parts: ..string) -> string {
	s, _ := filepath.join(parts, context.temp_allocator)
	return s
}

// What a program said and how it ended.
Ran :: process.Ran

// This process's environment for a child. Determinate Nix's lazy trees lock a git source with submodules (socle's own)
// with a hash that a later evaluation refuses: socle's nix calls do without them (a Nix that has no such setting says
// so on its standard error, and goes on).
child_env :: proc() -> []string {
	env, _ := os.environ(context.temp_allocator)
	out := make([dynamic]string, context.temp_allocator)
	given := ""
	for e in env {
		if strings.has_prefix(e, "NIX_CONFIG=") { given = e[len("NIX_CONFIG="):]; continue }
		append(&out, e)
	}
	append(&out, strings.concatenate({"NIX_CONFIG=", given, given != "" ? "\n" : "", "lazy-trees = false"}, context.temp_allocator))
	return out[:]
}

// Runs `command` in `dir` ("": this process's) and waits; its output in `allocator`.
run :: proc(command: []string, dir := "", allocator := context.allocator) -> Ran {
	return process.run(command, {dir = dir, env = child_env()}, allocator)
}

// Runs `command` with `input` on its standard input (a password: never on its command line, which any process can
// read), and waits; its output in the temporary memory.
run_input :: proc(command: []string, input: string) -> Ran {
	return process.run(command, {env = child_env(), input = input}, context.temp_allocator)
}

// Runs `command` on this terminal (it asks its own questions there), and waits; its standard output in the temporary
// memory.
run_terminal :: proc(command: []string) -> (r: Ran) {
	r.code = -1
	out_r, out_w, oerr := process.pipe()
	if oerr != nil { return }
	p, e := process.start({command = command, env = child_env(), stdin = os.stdin, stdout = out_w, stderr = os.stderr})
	os.close(out_w)
	if e != nil { os.close(out_r); return }
	r.started = true
	out, _ := os.read_entire_file_from_file(out_r, context.temp_allocator)
	os.close(out_r)
	state, _ := os.process_wait(p)
	r.stdout = string(out)
	if state.exited { r.code = state.exit_code }
	r.ok = state.exited && state.exit_code == 0
	return
}

// Runs `command` and gives each line of its standard error to `line` as it comes (a build's log), then waits.
// Its standard output (a path, a result) comes back whole.
run_lines :: proc(command: []string, dir: string, line: proc(user: rawptr, text: string), user: rawptr, allocator := context.allocator) -> (r: Ran) {
	r.code = -1
	err_r, err_w, perr := process.pipe()
	if perr != nil { return }
	out_r, out_w, oerr := process.pipe()
	if oerr != nil { os.close(err_r); os.close(err_w); return }
	p, e := process.start({command = command, working_dir = dir, env = child_env(), stdout = out_w, stderr = err_w})
	os.close(err_w)
	os.close(out_w)
	if e != nil { os.close(err_r); os.close(out_r); return }
	r.started = true

	// (the standard output is small: a path; it is read after the log, so a full pipe of it never holds the child)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_stream(err_r))
	defer bufio.scanner_destroy(&scanner)
	// (a line of nix's log can be long: a whole error with its trace)
	scanner.max_token_size = 1 << 22
	for bufio.scanner_scan(&scanner) { line(user, bufio.scanner_text(&scanner)) }
	out, _ := os.read_entire_file_from_file(out_r, allocator)
	os.close(err_r)
	os.close(out_r)
	state, _ := os.process_wait(p)
	r.stdout = string(out)
	if state.exited { r.code = state.exit_code }
	r.ok = state.exited && state.exit_code == 0
	return
}
