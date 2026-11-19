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

At start, socle reads what it runs on, on a worker:

1. `/etc/NIXOS` exists: socle offers the system target, and a home for the person.
2. Nix exists without NixOS: socle offers a home.
3. No Nix: socle offers to install Nix (the Determinate Nix installer, through polkit), then a home.

## Refused

- **A system target outside NixOS** (system-manager, nix-darwin) in the first version. They are module systems too, so
  the model fits them; they wait until the two first targets work.
- **Home Manager as a NixOS module only.** A home must also work without NixOS, so socle uses Home Manager on its own
  for every home, NixOS or not: one path, one test.
