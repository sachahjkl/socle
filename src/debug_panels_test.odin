package socle

import "core:strings"
import "core:testing"
import "gt:debug"
import "gt:ui"

// Every panel lists on a bare State, with no window; the acts that need no worker reach their states
// (src/md/infrastructure/debug-panels.md).
@(test)
the_debug_panels_list_and_act_without_a_window :: proc(t: ^testing.T) {
	s: ui.State
	ui.init(&s, nil, nil)
	defer ui.destroy(&s)
	app := new(App)
	defer free(app)
	app.source = .Demo
	defer {
		build_log_destroy(&app.apply.log)
		delete(app.apply.failure)
		delete(app.eval_error)
		delete(app.load_error)
		index_destroy(&app.zones)
	}
	debug_panels_register(&s, app)

	sb := strings.builder_make(context.temp_allocator)
	debug.list(&s, &sb)
	all := strings.to_string(sb)
	for path in ([]string{"Folder/load", "Draft/evaluation error", "Apply/stage", "Apply/Log/lines kept", "Indexes/Time zones/state", "Installer"}) {
		testing.expectf(t, strings.contains(all, path), "the panels list %s", path)
	}

	// a page set from a tool
	testing.expect_value(t, debug.set(&s, "Folder/page", "Region"), "")
	testing.expect_value(t, app.page, Page.Region)

	// a failed read, an evaluation that fails then is cleared
	testing.expect_value(t, debug.press(&s, "Folder/Fail the read"), "")
	testing.expect_value(t, app.load, Load_State.Failed)
	testing.expect_value(t, debug.press(&s, "Draft/Fail the evaluation"), "")
	testing.expect_value(t, app.eval_error, SIMULATED)
	testing.expect_value(t, debug.press(&s, "Draft/Clear the error"), "")
	testing.expect_value(t, app.eval_error, "")

	// a long log: the oldest lines go, the count goes on
	testing.expect_value(t, debug.press(&s, "Apply/Log/Add lines"), "")
	testing.expect(t, len(app.apply.log.lines) <= LOG_KEPT + 1000, "the log keeps its bound")
	testing.expect(t, app.apply.log.next > u64(LOG_KEPT), "every line is counted")

	// a build that fails: the window's own failure, its lines kept to read
	testing.expect_value(t, debug.press(&s, "Apply/Fail the build"), "")
	testing.expect_value(t, app.apply.stage, Stage.Idle)
	testing.expect_value(t, app.apply.failure, SIMULATED)
	testing.expect(t, len(app.apply.log.lines) > 0, "the failed build's lines stay")

	// an index that fails, then is dropped: a new session's
	testing.expect_value(t, debug.press(&s, "Indexes/Time zones/Fail it"), "")
	testing.expect_value(t, app.zones.state, Index_State.Failed)
	testing.expect_value(t, debug.press(&s, "Indexes/Time zones/Drop"), "")
	testing.expect_value(t, app.zones.state, Index_State.Absent)
}
