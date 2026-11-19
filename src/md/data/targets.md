# Targets

socle drives a whole NixOS machine, or only Nix on another system. The stakes differ, so a **target** names what socle
manages, and each target keeps the same model: layers of data, features, a review, versions to go back to.

| Target | Where | What socle manages | Who applies | Folder |
|---|---|---|---|---|
| **System** | NixOS | the whole machine: boot, hardware, services, people, apps | the helper, as root | `/etc/socle` |
| **Home** | Nix on any Linux, or macOS | one person's apps, shell, settings and services, through Home Manager | the person | `~/.config/socle` |

A NixOS machine has both: the system target, and a home target for each person who wants one.

## One library, one model per target

- Each target is a module system: NixOS for the system, Home Manager for a home. The layers, the priorities, the
  features and `socle.ui` work the same way in both, because both are the same kind of module system.
- A feature exists for the targets where it means something. "Printing" is a system feature only; "Shell" and "Look"
  exist for both; "Apps" exists for both and writes `environment.systemPackages` or `home.packages`. A page appears
  when its target declares it.
- `socle.lib.configuration` returns `nixosConfigurations.<host>` for each file of `socle/hosts/`, and
  `homeConfigurations."<person>@<host>"` for each file of `socle/homes/`.

## What changes with the stakes

- **Root.** A home needs no root: no helper, no polkit. socle runs the activation of Home Manager as the person.
- **Try and keep.** A broken home does not take the screen or the network away: a home applies at once, and its
  previous generation stays one click away. The countdown is for the system only.
- **Templates.** A template says its target. A home template ("A developer's terminal", "A designer's apps") starts a
  home on any system with Nix.

## The start

At start, socle reads what it runs on, on a worker (source.odin, `load_work`):

1. No folder named and `/etc/NIXOS` exists: the system target, `/etc/socle`. `socle --home` opens the person's home on
   NixOS too.
2. No folder named, no NixOS: a home, `~/.config/socle`. Without one, the start page offers the home templates and
   writes the folder as the person (home.odin).
3. A folder named (`--folder`): its layers say its target (`socle/hosts` or `socle/homes`).
4. No Nix: socle's program comes through Nix today, so it does not run there yet. Installing Nix for the person waits
   for a program that runs without it (ROADMAP.md).

## As built

- The modules: `nix/shared` holds what both targets declare (the pages, the identity, the apps' options);
  `nix/modules` is the system's, `nix/home` the home's. A home's apps go to `home.packages`; its pages are Home
  Manager's own options (Shell, Development) and its base's tools.
- A home's own layer is `socle/homes/<person>@<host>.json`, Home Manager's way of naming a home: `home.username`,
  `home.homeDirectory`, `home.stateVersion`. The window evaluates `socleInfo."<person>@<host>"`, quoted for its `@`.
- The apply of a home builds `homeConfigurations."<name>".activationPackage`, then runs its `activate` as the person:
  no helper, no countdown, no "at the next start". Its versions are Home Manager's profile, in
  `~/.local/state/nix/profiles` (or `/nix/var/nix/profiles/per-user/<person>`); each holds `socle-revision`, as a
  system's does, so the history joins them to the folder's commits the same way.
- Free space of a home runs as the person (`nix-env --delete-generations`, `nix-collect-garbage`).
- A template says its target (`nix/templates/default.nix`); the gallery of a configuration lists its target's only.
  `src/demo/gallery.json` holds every template for the installer and the start of a home, which have no folder to
  evaluate yet.
- Tests: `checks.homes` builds tests/home and reads what it holds; `nix build .#tests.home` builds and activates it as
  its person in a virtual machine.

## Refused

- **A system target outside NixOS** (system-manager, nix-darwin) in the first version. They are module systems too, so
  the model fits them; they wait until the two first targets work.
- **Home Manager as a NixOS module only.** A home must also work without NixOS, so socle uses Home Manager on its own
  for every home, NixOS or not: one path, one test.
