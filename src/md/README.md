# socle: intent

socle is a control panel for a whole NixOS system, or for a person's Nix setup on any other system
([data/targets.md](data/targets.md)). It owns one configuration: it creates it from a template, changes it from forms,
builds it, switches to it, and goes back to an earlier generation. It is also the installer of socle's own live images,
a NixOS with opinions ([features/images.md](features/images.md)). This folder follows
<https://srcmd.org>. It records why the design has its shape. The screens are in [docs/mockups](../../docs/mockups/README.md).

## The idea that makes the problem small

A tool that edits Nix code must parse it, understand it and write it back without damage. That problem has no good
solution, and socle refuses it. **socle writes data, and a fixed Nix library turns the data into a system.**

- The configuration is a set of **layers**: JSON documents of option values. A template is a layer. The person's
  choices are a layer. ([data/configuration.md](data/configuration.md))
- socle's Nix library makes one NixOS module of each layer, with a priority for each. The NixOS module system does
  the merge. socle reimplements no merge.
- The forms come from the option declarations of NixOS and of socle's **features**: type, default, description. There
  is no second schema. ([features/features.md](features/features.md))
- What data cannot say (a function, an overlay, a package built from source) goes in `custom/*.nix`. The person writes
  it; socle imports it and never reads it.

So socle reads and writes JSON, and runs `nix` and `git`. The configuration stays a plain flake that builds without
socle.

## Overview

- The window's thread draws and never waits. Workers own every `nix`, `git` and D-Bus call:
  - the **evaluator** evaluates the draft after each change, and gives back its errors and its option values;
  - the **builder** builds a system and streams the progress of `nix` (`--log-format internal-json`);
  - the **catalogue** builds and keeps the indexes of options and packages for the locked Nixpkgs.
- The **helper** (`socle-helper`) is a small system service. It is the only part that runs as root. It switches to a
  built system, or back to a generation. ([infrastructure/helper.md](infrastructure/helper.md))
- socle's NixOS module is part of every configuration that socle manages: it installs the helper, the polkit rule and
  socle itself. A system that socle installed can always run socle.

## State machines

- **Three versions of the system.** The *draft* (the layers on disk), the *applied* version (the last commit of the
  configuration's git repository) and the *running* version (the current generation). The window shows the distance
  between them: "3 changes not applied", "applied, starts at the next boot".
- **An apply.** Evaluate, review, build, authorise, switch, record. One at a time, for the whole machine.
  ([features/apply.md](features/apply.md))
- **The evaluation of the draft.** Idle, waiting (a short delay after the last keystroke), evaluating, then valid or
  invalid. A newer draft cancels the older evaluation; only the newest result is shown.
- **The indexes of the catalogue.** For each lock of Nixpkgs: absent, building, ready or failed. A change of lock
  starts a new build; the old index serves until the new one is ready.
- **An input that moves.** Nixpkgs, socle's library and each template are flake inputs. Each one is up to date, has an
  update available, or has an update in review. Updates use the same review as any change.
- **The installer.** Disk, person, template, review, install, first start. Each step can go back until the disk is
  written. ([features/installer.md](features/installer.md))

## Subtleties

- A switch can stop the session: a new display manager, a new graphics driver. The helper runs the switch in a
  systemd unit of its own, and writes its result. If the window dies, the next start reads the result.
- A layer's priority goes on each option, never on a whole tree: a person's `users.users.ada` must not discard the
  system users that the modules define. ([data/configuration.md](data/configuration.md))
- socle's collections are sets keyed by name, never lists: a higher layer can remove what a lower layer added
  (`packages.vlc = false`). A NixOS list gets the person's items added to the modules' items; to replace the whole
  list is an explicit choice.
- A flake in a git repository sees only the files that git knows. socle adds every file that it creates to the index
  at once (`git add`), and asks the person to add theirs when `custom/` holds a file that git does not know.
- Each generation records the hash of the layers that made it (`$toplevel/socle-revision`). The history joins
  generations and commits by this hash, not by a commit that must exist before the build.
- The person's draft is never lost: an apply that fails keeps the draft as it is, and the window points at the cause.

## The first tests

These tests come before any window, because each one can break the design:

- **The layers keep the modules' values.** A template adds `vlc` and a printer; the person removes `vlc` and adds the
  account `ada` with a group. The evaluated system has no `vlc`, has `ada` in that group, and still has `root`, the
  system users and the modules' packages.
- **The eject.** Each shipped template, with a sample person's layer, evaluates with plain `nix eval` and builds a
  `toplevel` with `nix build`, without the socle program.
- **The revert.** In a virtual machine (opt-in): a try that breaks the network, no "Keep", and the machine runs the
  previous version after the countdown.

## File Index

- [data/configuration.md](data/configuration.md): the folder that socle manages, the layers, their JSON form, the
  priorities, the generated flake, the eject
- [data/targets.md](data/targets.md): the system target (NixOS) and the home target (Nix anywhere), what the stakes
  change, what socle does at start
- [data/templates.md](data/templates.md): what a template is, how one extends another, how a template is followed,
  shared and published
- [features/features.md](features/features.md): a feature is a NixOS module with options under `socle.*`; how its
  options become a page of settings
- [features/apply.md](features/apply.md): the pipeline from a draft to a running system, the review, the history and
  the return to a generation
- [features/apps.md](features/apps.md): the package index of the locked Nixpkgs, the search, the system's apps and a
  person's apps
- [features/all-settings.md](features/all-settings.md): every NixOS option, its value and its source layer, which
  values data can hold and which ones go to `custom/`
- [features/window.md](features/window.md): the pages, the bar of changes, the words that the window uses for Nix's
  concepts
- [features/installer.md](features/installer.md): the install from the live image, the disk, the hardware, the first
  start
- [features/region.md](features/region.md): the time zone, the language and the keyboard after the install: why they
  live in the person's layer, the zones searched with their offsets, the short lists of the installer
- [features/images.md](features/images.md): socle's live images, the base of every system (Determinate Nix, nh,
  nix-output-monitor), the command line
- [infrastructure/helper.md](infrastructure/helper.md): the root service, its verbs, its checks, polkit, the switch
  that outlives the window
- [infrastructure/debug-panels.md](infrastructure/debug-panels.md): the debug panels, one per state machine; values
  watched where a change would lie, acts that simulate through the real paths, the demo's own simulations
