# Commands

## socle

| Command | What it does |
|---|---|
| `socle` | The window on this machine: its system on NixOS (`/etc/socle`), your home elsewhere (`~/.config/socle`) |
| `socle --home` | The window on your home, on NixOS too |
| `socle --folder=<path>` | The window on another folder that Socle manages |
| `socle --demo` | The window on a demo system: nothing is read, built or changed |
| `socle --page=<name>` | Open on a page: `overview`, `apps`, `people`, `desktop`, `updates`, `history`, `templates`, `settings`, or a feature's page (`hardware`, `network`...) |
| `socle --light` | The light theme |
| `socle install` | The installer's window |
| `socle install --disk=... --yes` | The install in a terminal (below) |
| `socle version` | Socle's version |

Without Socle installed, put `nix run github:sachahjkl/socle --` in front: `nix run github:sachahjkl/socle -- --demo`.

## socle install, in a terminal

Run it as root (`sudo`) from a live image. It erases the disk.

| Flag | What it sets | Default |
|---|---|---|
| `--disk=<path>` | The whole disk to erase; a `/dev/disk/by-id/...` path stays the same when disks move | needed |
| `--template=<ref>` | The template: `socle#minimal`, `socle#home-server`, `socle#family-desktop`, `socle#gaming`, `socle#developer` | needed |
| `--host=<name>` | The computer's name: lowercase letters, digits, dashes | needed |
| `--login=<login>` | The first account, an administrator | needed |
| `--name=<full name>` | The account's full name | the login |
| `--encrypt` | Encrypt the disk; the passphrase is asked | off |
| `--locale=<locale>` | The language | `en_US.UTF-8` |
| `--keyboard=<layout>` | The keyboard, an XKB layout: `us`, `fr`, `de`... | `us` |
| `--zone=<zone>` | The time zone: `Europe/Paris`... | `UTC` |
| `--password-hash=<hash>` | The password's hash, in place of the question (`mkpasswd -m yescrypt`) | asked |
| `--yes` | Erase and install. Without it, Socle says what it would erase and stops | off |

## The helper

The window runs as you. Only Socle's helper changes the system, as root, through `pkexec` and polkit's action
`software.froment.socle.apply`. It takes fixed verbs, and checks each store path that it gets:

| Verb | What it does |
|---|---|
| `try <path>` | Runs a version on trial; a timer goes back in 60 seconds |
| `keep` | The version on trial becomes the default, for the next start too |
| `revert` | The version before the trial runs again |
| `boot <path>` | A version becomes the default at the next start; nothing runs now |
| `collect <n>` | Removes the versions beyond the newest `n`, then collects the store's garbage |
| `init <template>` | Takes the machine over: writes `/etc/socle` |
| `install <folder>` | Installs a folder that the installer wrote on its disk |

You do not need to run them yourself: the window does.

## Other tools of the base

| Command | What it does |
|---|---|
| `nh os switch` | Builds and switches `/etc/socle`, with a tree of the build |
| `nh clean all --keep 10` | Removes old versions, as Free space does |
| `nom build ...` | `nix build` with a tree of what downloads and builds |
| `sudo nixos-rebuild switch --flake /etc/socle#<host>` | NixOS's own way, on the same folder |
