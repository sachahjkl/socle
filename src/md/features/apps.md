# Apps

## The index

The search needs the names, versions and descriptions of every package of the locked Nixpkgs, about 120 000. A
`nix search` evaluates Nixpkgs at each query: tens of seconds. socle keeps an index per revision of Nixpkgs, in
`~/.cache/socle/index/<revision>`.

1. The channels publish `packages.json.br` for each of their revisions. socle downloads the one of the locked
   revision.
2. If the lock points at a revision that no channel published, the catalogue worker builds the index with one
   evaluation of Nixpkgs, once.

The worker loads the index in memory and answers each query (name, then description) with the first 200 results. The
window shows the old index until a new one is ready.

## The system and a person

- An app for every person is `socle.packages.<name> = true` (into `environment.systemPackages`).
- An app for one person is `socle.people.<name>.packages.<name> = true` (into `users.users.<name>.packages`).
- Both are sets keyed by name: the person can remove an app that the template added.

## Free or not

A package whose licence is not free shows "Not free". Its addition also sets `socle.unfree.<name> = true`, which the
library gives to `nixpkgs.config.allowUnfreePredicate`. There is no global "allow every non-free package": the person
sees each one.

## What the page shows first

The index does not say which package has a window. The first view is a list of popular apps that socle's library
keeps, with icons and categories ("Internet", "Office", "Graphics", "Games"). The search covers every package.

## Refused

- **A guess of the graphical packages** from names or dependencies: wrong too often.
- **`nix-env -i` or `nix profile`**: imperative, outside the configuration, lost by the next template change.
