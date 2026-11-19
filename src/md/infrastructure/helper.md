# The helper

`socle-helper` is the only part of socle that runs as root. It is a D-Bus service on the system bus
(`software.froment.Socle1`, through gt:dbus), started by systemd on demand. socle's NixOS module installs it with its
polkit action, so every system that socle manages has it.

## The verbs

| Verb | What it does |
|---|---|
| `Try(path)` | activate `path` without making it the default, then start the countdown |
| `Keep()` | make the tried path the default: the system profile and the boot entry |
| `Revert()` | activate the previous default again, stop the countdown |
| `Boot(path)` | make `path` the default for the next start; activate nothing now |
| `Collect(keep)` | remove the generations beyond the last `keep`, then collect the garbage |
| `Status()` | the state, the tried path, the time left, the result of the last verb |

There is no verb that takes a command line, a file name or an option.

## The checks

Before a `Try` or a `Boot`, the helper checks that `path` is a valid path of the Nix store, that it has
`bin/switch-to-configuration`, and that it has `socle-revision` (made by socle's library). Every verb needs the polkit
action `software.froment.socle.apply` (`auth_admin_keep`). The checks protect against a mistake, not against an
administrator: an administrator can already do anything.

## The switch outlives the window and the helper

- The activation can restart the display manager and end the session, and the window with it. The helper runs it in a
  transient unit (`systemd-run --unit=socle-activate`) and writes the result to `/run/socle/state.json`. A window that
  starts reads the result.
- The countdown is a transient timer (`socle-revert.timer`). If the helper itself dies, the timer still goes back.
- The activation of a new system can change the helper's own unit. The unit has `restartIfChanged = false`: the
  helper stays the one that started the try until it ends.

## The state

```
idle ─Try─▶ trying ─Keep─▶ keeping ─▶ idle
              │
              └─Revert or timer─▶ reverting ─▶ idle
idle ─Boot─▶ booting ─▶ idle
idle ─Collect─▶ collecting ─▶ idle
```

A verb that does not match the state is refused with the state's name. The state lives in `/run/socle/state.json`, so
a restart of the helper continues it.
