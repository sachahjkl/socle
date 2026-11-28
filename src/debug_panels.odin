package socle

// The debug panels: one per state machine of socle's, its values watched and acts that reach its hard states through
// the program's own paths (src/md/infrastructure/debug-panels.md).

import "core:fmt"
import "core:strings"
import "gt:debug"
import "gt:ui"

// What a simulation says, so that nobody takes it for a real failure.
SIMULATED :: "simulated by the debug panel"

// The changes and the log lines a panel lists.
@(private = "file") LIST_MAX :: 20
// The lines "Add lines" adds to the build's log: more than LOG_KEPT, so the oldest are dropped.
@(private = "file") LOG_STRESS :: LOG_KEPT + 1500

debug_panels_register :: proc(s: ^ui.State, app: ^App) {
	debug.panel(s, "Folder", folder_debug, app)
	debug.panel(s, "Draft", draft_debug, app)
	debug.panel(s, "Apply", apply_debug, app)
	debug.panel(s, "Indexes", indexes_debug, app)
	debug.panel(s, "Installer", installer_debug, app)
}

@(private = "file")
folder_debug :: proc(app: ^App) {
	debug.watch("source", app.source)
	debug.watch("target", app.target)
	debug.watch("folder", app.folder)
	debug.watch("host", app.host)
	debug.watch("load", app.load)
	debug.watch("loading", app.loading)
	debug.watch("load error", app.load_error)
	debug.watch("versions", len(app.generations))
	debug.choice("page", &app.page)
	debug.toggle("about", &app.about_open)
	if debug.act("Read again") && !app.loading { load_start(app) }
	if debug.act("Fail the read") {
		app.load = .Failed
		delete(app.load_error)
		app.load_error = strings.clone(SIMULATED)
	}
}

@(private = "file")
draft_debug :: proc(app: ^App) {
	debug.watch("changes", len(app.changes))
	debug.watch("evaluating", app.evaluating)
	debug.watch("evaluation due (ms)", app.eval_due_ms)
	debug.watch("evaluation error", app.eval_error)
	// (the evaluator runs at the next build: only a folder has one)
	if debug.act("Evaluate now") && app.source == .Folder { app.eval_due_ms = 1 }
	if debug.act("Fail the evaluation") {
		delete(app.eval_error)
		app.eval_error = strings.clone(SIMULATED)
	}
	if debug.act("Clear the error") {
		delete(app.eval_error)
		app.eval_error = ""
	}
	if debug.act("Discard the draft") { draft_discard(app) }
	// (sections last: an unindented item after a section looks like a misaligned child of it)
	if debug.section("Changes", open = false) {
		for c, i in app.changes {
			if i >= LIST_MAX { break }
			debug.watch(fmt.tprintf("%d", i), fmt.tprintf("%s: %s", c.page, c.text))
		}
	}
}

@(private = "file")
apply_debug :: proc(app: ^App) {
	a := &app.apply
	debug.watch("stage", a.stage)
	debug.watch("at the next start", a.now == 1)
	debug.watch("back to a version", a.back)
	debug.watch("summary", a.summary)
	debug.watch("path", a.path)
	debug.watch("failure", a.failure)
	// (before the sections: a top-level act right below Log sat glued under Log's indented acts)
	// (a stage that the helper holds is not the window's to end: a version on trial has its timer on the machine)
	if a.stage == .Idle || a.stage == .Preparing {
		if debug.act("Fail the build") {
			if len(a.log.lines) == 0 { log_stress(&a.log) }
			apply_failed(app, SIMULATED)
		}
	} else {
		debug.note("The helper holds this stage: nothing is simulated until it ends.")
	}
	if debug.section("Progress") {
		p := a.progress
		debug.watch("built", fmt.tprintf("%d of %d", p.builds_done, p.builds_expected))
		debug.watch("downloaded", fmt.tprintf("%d of %d", p.paths_done, p.paths_expected))
		debug.watch("bytes", fmt.tprintf("%d of %d", p.bytes_done, p.bytes_expected))
		debug.watch("doing", p.doing)
	}
	if debug.section("Log") {
		debug.toggle("open", &a.log.open)
		debug.watch("lines kept", len(a.log.lines))
		debug.watch("lines said", a.log.next)
		if debug.act("Add lines") { log_stress(&a.log) }
		if debug.act("Clear") { build_log_clear(&a.log) }
	}
}

// More lines than the log keeps: the drop of the oldest, and the view at its end with thousands of them.
@(private = "file")
log_stress :: proc(l: ^Build_Log) {
	lines := make([]string, LOG_STRESS, context.temp_allocator)
	base := l.next
	for &s, i in lines { s = fmt.aprintf("debug> line %d of a long build", base + u64(i)) }
	build_log_add(l, lines)
}

@(private = "file")
indexes_debug :: proc(app: ^App) {
	index_debug("Packages", &app.catalogue)
	index_debug("Options", &app.options_index)
	index_debug("Time zones", &app.zones)
}

@(private = "file")
index_debug :: proc(name: string, index: ^Index) {
	if debug.section(name) { index_items(index) }
}

@(private = "file")
index_items :: proc(index: ^Index) {
	debug.watch("state", index.state)
	debug.watch("entries", len(index.entries))
	debug.watch("why", index.why)
	debug.watch("query", index.query)
	debug.watch("asked", index.asked)
	debug.watch("answered", index.answered)
	debug.watch("hits", len(index.hits))
	// (a drop is a new session's index: the next page that needs it reads it again)
	if index.state == .Building || (index.answered != index.asked && index.answered != -1) {
		debug.note("A worker reads it: Drop and Fail wait for its answer.")
		return
	}
	if debug.act("Drop") { index_drop(index) }
	if debug.act("Fail it") && index_drop(index) { index.state, index.why = .Failed, strings.clone(SIMULATED) }
}

@(private = "file")
installer_debug :: proc(app: ^App) {
	ins := app.installer
	if ins == nil {
		debug.note("socle runs on a folder: the installer opens with `socle install`.")
		return
	}
	debug.choice("page", &ins.page)
	debug.watch("time zone", ins.zone)
	debug.toggle("online", &ins.online)
	debug.watch("disks", len(ins.disks))
	debug.watch("disk", ins.disk)
	debug.watch("step", ins.step)
	debug.watch("running", ins.running)
	debug.watch("done", ins.done)
	debug.watch("why", ins.why)
	// (a real install's worker cannot be stopped from here: it formats a disk)
	if app.source != .Demo {
		debug.note("Fail the install acts in the demo only.")
	} else if debug.act("Fail the install") && ins.running {
		ins.running = false
		delete(ins.why)
		ins.why = strings.clone(SIMULATED)
	}
}
