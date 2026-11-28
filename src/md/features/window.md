# The window

## The pages

A sidebar, as in classeur and inspecteur, with three groups:

- **Overview** (no group): the running version, its template, the state of the updates, the space that old versions
  take, the shortcuts to the pages that people use most.
- **System**: Apps, People, Desktop, Hardware, Sound, Network, Printing, Gaming, Sharing, Start and power. The list
  comes from `socle.ui.pages`: a template can add a page.
- **Manage**: Updates, History, Templates, All settings.

The palette (Ctrl+K, the toolkit's) finds a page, an app, any option, any action.

## About and What's new

- The info button in the title bar opens `ui.about_modal`: socle's logo (`assets/logo_128.png`), version, toolkit
  version, MIT licence, links (Website, Online release notes, Repository, Docs), Copy version, Copy diagnostics
  (target, host, NixOS release, renderer), and **What's new** as the primary action.
- **What's new** (`Page.Whats_New`) embeds `CHANGELOG.md` and renders its releases through `gt:markdown`
  (`markdown.view`: cached across frames, selectable text, clickable links). It opens from About (and
  `--page=whats-new`) and is not listed in Manage, which holds the system's own controls. When no configuration is
  loaded yet, a Back link returns to the page before it.

## The bar of changes

A bar at the bottom of every page, shown only when the draft differs from the applied version: "3 changes", "Review",
"Discard". During an apply, the same bar shows the stage and its progress, so the person can keep browsing. The bar is
the only place that says that changes wait: the pages mark each changed value with a dot and say nothing more.

## Words

The window uses the person's words. The NixOS words appear only in All settings and with the "expert words"
preference.

| NixOS | socle |
|---|---|
| generation | version ("Version 214") |
| rebuild, switch | apply |
| build (a derivation) | prepare |
| flake input | source |
| Nixpkgs | the software catalogue |
| garbage collection | free space |
| option | setting |
| module (in `custom/`) | code |

## As built

- **One model, two sources** (`src/model.odin`, `src/source.odin`). What the window shows is an evaluation of the
  folder (`socleInfo` of the library: the values that result, the templates' values, the facts of each page's options,
  the pages, the popular apps with their versions, the gallery) and the person's layer as a JSON tree. `--demo` reads
  a kept evaluation of `tests/demo` (`src/demo/info.json`, made by `socletool demo`): the demo and a real system go
  through the same pages and the same code.
- **A value shown** is the draft's when the draft sets it, else the evaluation's. A value set equal to the template's
  is not kept: the template's shows again. The evaluator evaluates the folder `EVAL_DELAY_MS` after the last change;
  its answer replaces the evaluation, or says why the draft does not evaluate (the review then refuses to apply).
- **The pages of NixOS's own options** (Hardware, Sound, Network, Printing, Gaming, Sharing, Start and power) come
  from `socle.ui.pages` (`nix/modules/pages.nix`): each option's control from its type (a switch, a segmented choice,
  a number), its title from its description. A page added by a template shows the same way.
- **The apply** (`src/apply.odin`): `nix build --log-format internal-json` on a worker, its progress posted to the
  bar (downloads, builds, what it does now); then `pkexec socle helper try` and the countdown; keep, go back, or the
  helper's timer; then the commit of the layers. In the demo, preparing is a clock and the helper is the window.
- **The versions** are the generations of `/nix/var/nix/profiles/system`, each joined to the commit whose layers'
  hash it carries (`socle-revision`).
- **No configuration in the folder**: the setup page writes `/etc/socle` from a template (`socle helper init`), with
  this machine's hardware (`nixos-generate-config`) and its people (`/etc/passwd`, administrators from `wheel`).

`socletool film` drives the demo headless on the graphics card (`tools/socle_film`, gt:film): the site's film and its
pictures come from it. `nix run .#vm` starts a virtual machine that socle manages for real (`nix/vm.nix`).

## At rest

The window does no work at rest. The evaluator, the builder and the catalogue sleep until a change, a query or an
apply. The Overview's state of the updates comes from a check at start and then once a day, on a worker.
