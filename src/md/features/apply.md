# Apply

## The draft

- The draft is the layers on disk. Each change of a control writes its layer at once: there is no Save button and
  nothing to lose when the window closes. The window keeps an undo history for its session (gt:undo).
- "Discard" brings the layers back to the last commit.
- The bar of changes counts the values that differ from the applied version. It is the JSON difference of the layers
  against `HEAD`, put in words with the titles of the options.

## The pipeline

```
draft ─▶ evaluate ─▶ review ─▶ build ─▶ try ─▶ keep ─▶ record
              │          │        │        │
              ▼          ▼        ▼        ▼ (no answer in 60 s, or "Go back")
          invalid     cancel   failed    revert
```

1. **Evaluate.** `nix eval` of the system's `drvPath`. An error stays on the draft and points at its option.
2. **Review.** The changes in words, grouped by page. A change that restarts the session (a new desktop, a new graphics
   driver, a new kernel) is marked: socle proposes "At the next start" in place of "Now".
3. **Build.** `nix build --log-format internal-json`, as the person, through the Nix daemon. The progress shows what is
   downloaded and what is built, with sizes. "Cancel" stops the process; nothing changes.
4. **Try.** The helper activates the new system without making it the default (`switch-to-configuration test`). The
   window asks "Keep this version?" with a countdown of 60 seconds.
5. **Keep.** The helper makes the system the default for the next start (the profile and the boot entry).
6. **Record.** socle commits the layers. The commit message is the review's summary.

"At the next start" skips steps 4 and 5: the helper sets the profile and the boot entry, and nothing is activated now.

## Why try before keep

A change of network or of display can leave the person without a working screen or connection. As a display settings
dialog does, the helper goes back by itself if nobody says "Keep". The countdown runs in the helper, not in the window,
so a crash of the session also goes back. ([../infrastructure/helper.md](../infrastructure/helper.md))

## The history

- The history lists the generations of `/nix/var/nix/profiles/system`: number, date, and the summary of the commit
  whose layers made it. The join is the hash of the layers, written by the library in `$toplevel/socle-revision`.
- A generation that socle did not make (an `nixos-rebuild` by hand) shows "made outside socle".
- "Go back to this version" runs the same try and keep with that generation's path; nothing is built.
- After a return, the running system and the draft differ. The window says so once and offers "Use its settings": the
  layers of that commit become the draft.
- "Free space" removes the generations beyond the newest ten, then collects the store's garbage
  (`socle helper collect 10`). The button shows only when there are more than ten. The window shows nix's summary
  of the space freed. Ten is a constant (`KEEP_VERSIONS`), not a preference: no person asked for another count.

## Subtle points

- One apply at a time per machine: a lock file in `/etc/socle/.git/socle.lock` holds the pipeline; a second window
  shows the first one's progress.
- The commit happens after the keep, not before the build: the revision in the system is the hash of the layers, which
  exists before any commit. A failed build leaves no commit to undo.
- A build is never wasted: a failed try keeps the built path, and a second apply of the same draft starts at "try".
