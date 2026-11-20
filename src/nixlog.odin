package socle

// nix's log (--log-format internal-json): activities start and stop, report their progress, and errors are messages
// of level 0. The apply's build and the installer read it the same way.

import "base:runtime"
import "core:encoding/json"
import "core:strings"

Nix_Log :: struct {
	kinds:    map[u64]int,   // an activity's id -> its type
	bytes:    map[u64]i64,   // a download's bytes done
	progress: Progress,
	errors:   strings.Builder,
	// The lines a person reads (what starts, what a build prints, the messages), owned, since the reader last took
	// them (nix_log_take); kept only with `keep_lines`: a reader that never takes them would hold the whole build.
	keep_lines: bool,
	lines:    [dynamic]string,
}

nix_log_init :: proc(l: ^Nix_Log) {
	l.kinds = make(map[u64]int)
	l.bytes = make(map[u64]i64)
	l.errors = strings.builder_make()
}

nix_log_destroy :: proc(l: ^Nix_Log) {
	delete(l.kinds)
	delete(l.bytes)
	delete(l.progress.doing)
	strings.builder_destroy(&l.errors)
	for s in l.lines { delete(s) }
	delete(l.lines)
}

// The lines said since the last take, the caller's now (nil: none).
nix_log_take :: proc(l: ^Nix_Log) -> []string {
	if len(l.lines) == 0 { return nil }
	out := make([]string, len(l.lines))
	copy(out, l.lines[:])
	clear(&l.lines)
	return out
}

@(private = "file")
nix_log_keep :: proc(l: ^Nix_Log, text: string) {
	if !l.keep_lines { return }
	t := strings.trim_right_space(strip_colours(text))
	if t == "" { return }
	append(&l.lines, strings.clone(t))
}

// The errors that nix said, colours removed.
nix_log_errors :: proc(l: ^Nix_Log) -> string { return strings.trim_space(strings.to_string(l.errors)) }

// One line of a log: false when it is not nix's.
nix_log_line :: proc(l: ^Nix_Log, text: string) -> bool {
	if !strings.has_prefix(text, "@nix ") { return false }
	// (a build says millions of lines and nothing frees the temporary memory until it ends: each line's goes with it)
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	v, err := json.parse_string(text[5:], parse_integers = true, allocator = context.temp_allocator)
	if err != nil { return true }
	o, _ := v.(json.Object)
	id := u64(num(o["id"]))
	switch str(o["action"]) {
	case "start":
		kind := int(num(o["type"]))
		l.kinds[id] = kind
		words := str(o["text"])
		nix_log_keep(l, words)
		if (kind == ACT_BUILD || kind == ACT_COPY_PATH) && words != "" {
			delete(l.progress.doing)
			l.progress.doing = strings.clone(words)
		}
	case "stop":
		delete_key(&l.kinds, id)
	case "result":
		fields := arr(o["fields"])
		switch int(num(o["type"])) {
		case RES_PROGRESS:
			if len(fields) < 2 { break }
			done, expected := int(num(fields[0])), int(num(fields[1]))
			switch l.kinds[id] {
			case ACT_BUILDS:     l.progress.builds_done, l.progress.builds_expected = done, expected
			case ACT_COPY_PATHS: l.progress.paths_done, l.progress.paths_expected = done, expected
			case ACT_COPY_PATH, ACT_FILE_TRANSFER:
				l.bytes[id] = i64(done)
				total: i64
				for _, n in l.bytes { total += n }
				l.progress.bytes_done = total
			}
		case RES_SET_EXPECTED:
			if len(fields) >= 2 && int(num(fields[0])) == ACT_COPY_PATH { l.progress.bytes_expected = i64(num(fields[1])) }
		case RES_BUILD_LOG_LINE, RES_POST_BUILD_LOG_LINE:
			if len(fields) >= 1 { nix_log_keep(l, str(fields[0])) }
		}
	case "msg":
		nix_log_keep(l, str(o["msg"]))
		if int(num(o["level"])) == 0 {
			strings.write_string(&l.errors, strip_colours(str(o["msg"])))
			strings.write_byte(&l.errors, '\n')
		}
	}
	return true
}

// nix's activity and result types (src/libutil/logging.hh)
@(private = "file") ACT_COPY_PATH     :: 100 + 1
@(private = "file") ACT_FILE_TRANSFER :: 100 + 2
@(private = "file") ACT_COPY_PATHS    :: 100 + 4
@(private = "file") ACT_BUILDS        :: 100 + 5
@(private = "file") ACT_BUILD         :: 100 + 6
@(private = "file") RES_PROGRESS      :: 100 + 5
@(private = "file") RES_SET_EXPECTED  :: 100 + 6
@(private = "file") RES_BUILD_LOG_LINE :: 100 + 1
@(private = "file") RES_POST_BUILD_LOG_LINE :: 100 + 7

// The escapes of a terminal's colours, which nix puts in its messages.
strip_colours :: proc(s: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	for i := 0; i < len(s); i += 1 {
		if s[i] == 0x1b && i + 1 < len(s) && s[i + 1] == '[' {
			j := i + 2
			for j < len(s) && !(s[j] >= '@' && s[j] <= '~') { j += 1 }
			i = j
			continue
		}
		strings.write_byte(&b, s[i])
	}
	return strings.to_string(b)
}
