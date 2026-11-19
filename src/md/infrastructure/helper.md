# The helper

`socle helper <verb>` is the only part of socle that runs as root. The window runs it through `pkexec`; polkit's
action `software.froment.socle.apply` (`auth_admin_keep`) names the installed program's path, so an administrator
types a password once per five minutes. socle's NixOS module installs the program and the action, so every system that
socle manages has them. Code: `src/helper.odin`.

## Why pkexec and not a service

A D-Bus service was the first design: a daemon started on demand, its own state, its own bus policy. pkexec gives the
same guarantees with none of it: polkit asks the password, the verbs are fixed, and the countdown already lives in
systemd (below), not in the helper. The helper is a short process per verb; its state is a file.

## The verbs

| Verb | What it does |
|---|---|
| `try <path>` | starts the countdown, then activates `path` without making it the default (`switch-to-configuration test`) |
| `keep` | makes the tried path the default: the system profile and the boot entry; stops the countdown |
| `revert` | activates the previous default again; stops the countdown |
| `boot <path>` | makes `path` the default for the next start; activates nothing now |
| `init <template>` | writes `/etc/socle` from a template: socle takes this machine over (`setup` page) |
| `collect <count>` | removes the generations beyond the last `count`, then collects the garbage |

There is no verb that takes a command line, a file name or an option.

## The checks

Before `try` and `boot`, the helper checks that `path` is a path of the store, valid (`nix-store --check-validity`),
with `bin/switch-to-configuration` and `socle-revision` (made by socle's library). The checks protect against a
mistake, not against an administrator: an administrator can already do anything. Every program it runs is named by its
absolute path under `/run/current-system/sw/bin`: pkexec gives a minimal `PATH`.

## The switch outlives the window and the helper

- `try` starts the countdown first: a transient timer of systemd (`socle-revert.timer`, `KEEP_SECONDS` after now)
  that runs `socle helper revert`. If the activation hangs, ends the session, or the window and the helper die, the
  timer still goes back.
- The activation runs in a transient unit (`socle-activate-<time>`): a new display manager may end the session that
  asked. Each activation and each countdown (`socle-revert-<time>`) gets a new unit name: a unit of the same name can
  still be loaded, and systemd then refuses the new one.
- One verb runs at a time: each takes a `flock` on `/run/socle/lock` and waits for it. `/run/current-system` changes
  in the middle of an activation, so a try asked just after the countdown went back can start while that switch
  still runs, and `switch-to-configuration` refuses a second switch. The kernel releases the lock when a helper
  ends, so a crashed helper does not block the next one.
- The state is `/run/socle/state.json` (`tried`, `previous`): `keep` and `revert` read it, and remove it. In `/run`,
  it does not survive a restart, and neither does a try: the default is still the previous version.

## The state

```
idle ─try─▶ trying ─keep─▶ idle (the tried version is the default)
              │
              └─revert, or the timer─▶ idle (the previous version runs)
idle ─boot─▶ idle (the default changes; nothing runs)
```

A `try` while a version is on trial is refused. A `keep` with nothing on trial is refused. A `revert` with nothing on
trial does nothing: the timer and a person's click can both come.

## Tested

`nix build .#tests.switch` (opt-in, `nix/tests.nix`): in a virtual machine managed by socle, a person's change is built
from `/etc/socle`, tried and left: the timer goes back; tried again and kept: it is the default; tried and reverted by
hand.
