# The debug panels

socle registers one debug panel (`gt:debug`) per area of its own state: **Folder**, **Draft**, **Apply**, **Indexes**
and **Installer**. Ctrl+Alt+Shift+D opens them beside the window; the devtools reach the same values and acts by path
(`tk cdp debug`, `debug-set`, `debug-press`). The toolkit's guide is [docs/debug.md](../../../ext/gui_toolkit/docs/debug.md).

## What they are for

- To see the state machines that the window only shows as their effects: the folder's read, the evaluator, the apply's
  stage, each index's query numbers, the installer's page.
- To reach the states that are hard to reach by hand, from a demo window, with no nix and no machine to break: a failed
  read, an evaluation error, a build that fails, a long build log, an index that fails or must be read again, a network
  that goes, an install that fails.

## Decisions

- **One panel per state machine**, named as the intent names it (apply.md, region.md, installer.md). A person who
  reads one file reads one panel.
- **Values are watched, not set, when a change would lie.** The apply's stage is the helper's too: a stage set by hand
  would show a version on trial that no timer brings back. It is shown, and the acts that change it go through the same
  procedures as the window (`apply_failed`), only where the window could reach that state itself.
- **The acts simulate through the real paths.** "Fail the build" is `apply_failed` with a sentence that says it was
  simulated; "Drop" empties an index as a new session has it, so the next page that needs it reads it again. Nothing
  writes a state that the program's own code never writes.
- **Simulations that would desync a real machine are the demo's only.** An install's worker cannot be stopped from the
  window: "Fail the install" acts in the demo, and says so elsewhere.
- **The page is set live.** The Folder panel's page and the Installer panel's page are choices: a tool or a person goes
  to any page, an installer's included, without the steps before it.
- **No string is edited.** `debug.text` keeps its own copy and the program's string is never freed: socle's owned
  strings (the folder, the errors) are watched only.

## Tests

`src/debug_panels_test.odin` runs every panel on a bare `ui.State` (no window, no fonts), with a demo App: it lists the
paths and presses the acts that need no worker.
