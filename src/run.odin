package socle

// Other programs (git, nix, pkexec), run on a worker, never on the interface's thread. Starting a process is not
// thread-safe (it changes which handles a child inherits): every start holds one lock.

import "core:bufio"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:sync"

@(private = "file") start_lock: sync.Mutex

// A path of `parts`, in the temporary memory.
join :: proc(parts: ..string) -> string {
	s, _ := filepath.join(parts, context.temp_allocator)
	return s
}

// What a program said and how it ended.
Ran :: struct {
	ok:     bool,     // it started and exited with 0
	code:   int,
	stdout: string,
	stderr: string,
}

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
run :: proc(command: []string, dir := "", allocator := context.allocator) -> (r: Ran) {
	env := child_env()
	sync.mutex_lock(&start_lock)
	state, out, err, e := os.process_exec({command = command, working_dir = dir, env = env}, allocator)
	sync.mutex_unlock(&start_lock)
	r.stdout, r.stderr = string(out), string(err)
	if e != nil {
		if r.stderr == "" { r.stderr = strings.clone(command[0], allocator) }
		return
	}
	r.code = state.exit_code
	r.ok = state.exited && state.exit_code == 0
	return
}

// Runs `command` with `input` on its standard input (a password: never on its command line, which any process can
// read), and waits; its output in the temporary memory.
run_input :: proc(command: []string, input: string) -> (r: Ran) {
	in_r, in_w, ierr := os.pipe()
	if ierr != nil { return }
	out_r, out_w, oerr := os.pipe()
	if oerr != nil { os.close(in_r); os.close(in_w); return }
	sync.mutex_lock(&start_lock)
	p, e := os.process_start({command = command, env = child_env(), stdin = in_r, stdout = out_w})
	sync.mutex_unlock(&start_lock)
	os.close(in_r)
	os.close(out_w)
	if e != nil { os.close(in_w); os.close(out_r); return }
	_, _ = os.write_string(in_w, input)
	os.close(in_w)
	out, _ := os.read_entire_file_from_file(out_r, context.temp_allocator)
	os.close(out_r)
	state, _ := os.process_wait(p)
	r.stdout = string(out)
	r.code = state.exit_code
	r.ok = state.exited && state.exit_code == 0
	return
}

// Runs `command` on this terminal (it asks its own questions there), and waits; its standard output in the temporary
// memory.
run_terminal :: proc(command: []string) -> (r: Ran) {
	out_r, out_w, oerr := os.pipe()
	if oerr != nil { return }
	sync.mutex_lock(&start_lock)
	p, e := os.process_start({command = command, env = child_env(), stdin = os.stdin, stdout = out_w, stderr = os.stderr})
	sync.mutex_unlock(&start_lock)
	os.close(out_w)
	if e != nil { os.close(out_r); return }
	out, _ := os.read_entire_file_from_file(out_r, context.temp_allocator)
	os.close(out_r)
	state, _ := os.process_wait(p)
	r.stdout = string(out)
	r.code = state.exit_code
	r.ok = state.exited && state.exit_code == 0
	return
}

// Runs `command` and gives each line of its standard error to `line` as it comes (a build's log), then waits.
// Its standard output (a path, a result) comes back whole.
run_lines :: proc(command: []string, dir: string, line: proc(user: rawptr, text: string), user: rawptr, allocator := context.allocator) -> (r: Ran) {
	env := child_env()
	err_r, err_w, perr := os.pipe()
	if perr != nil { return }
	out_r, out_w, oerr := os.pipe()
	if oerr != nil { os.close(err_r); os.close(err_w); return }
	sync.mutex_lock(&start_lock)
	p, e := os.process_start({command = command, working_dir = dir, env = env, stdout = out_w, stderr = err_w})
	sync.mutex_unlock(&start_lock)
	os.close(err_w)
	os.close(out_w)
	if e != nil { os.close(err_r); os.close(out_r); return }

	// (the standard output is small: a path; it is read after the log, so a full pipe of it never holds the child)
	tail := strings.builder_make(allocator)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_stream(err_r))
	defer bufio.scanner_destroy(&scanner)
	// (a line of nix's log can be long: a whole error with its trace)
	scanner.max_token_size = 1 << 22
	for bufio.scanner_scan(&scanner) {
		text := bufio.scanner_text(&scanner)
		line(user, text)
	}
	out, _ := os.read_entire_file_from_file(out_r, allocator)
	os.close(err_r)
	os.close(out_r)
	state, _ := os.process_wait(p)
	r.stdout = string(out)
	r.stderr = strings.to_string(tail)
	r.code = state.exit_code
	r.ok = state.exited && state.exit_code == 0
	return
}
