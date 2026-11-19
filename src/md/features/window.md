# The window

## The pages

A sidebar, as in classeur and inspecteur, with three groups:

- **Overview** (no group): the running version, its template, the state of the updates, the space that old versions
  take, the shortcuts to the pages that people use most.
- **System**: Apps, People, Desktop, Hardware, Sound, Network, Printing, Gaming, Sharing, Start and power. The list
  comes from `socle.ui.pages`: a template can add a page.
- **Manage**: Updates, History, Templates, All settings.

The palette (Ctrl+K, the toolkit's) finds a page, an app, any option, any action.

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

## At rest

The window does no work at rest. The evaluator, the builder and the catalogue sleep until a change, a query or an
apply. The Overview's state of the updates comes from a check at start and then once a day, on a worker.
