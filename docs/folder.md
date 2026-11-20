# The folder

Socle keeps a system in `/etc/socle`, and a home in `~/.config/socle`. The folder is a flake in git. Socle writes data
in it, never Nix code, so you can read it, keep it, and build it without Socle.

## What is in it

```
/etc/socle
├── flake.nix               written by Socle from socle/inputs.json: its inputs and one call to Socle's library
├── flake.lock              the exact versions of Nixpkgs, Socle and the templates
├── socle/
│   ├── inputs.json         the flake's inputs: Nixpkgs, Socle, the templates from links
│   ├── system.json         your layer: the template and your changes
│   └── hosts/<host>.json   this machine's layer: its disk, language, accounts' password hashes, release
├── hosts/<host>/           this machine's hardware: facter.json (an install) or hardware.nix (a takeover)
└── custom/*.nix            your own Nix code, imported as it is
```

A home has `socle/homes/<you>@<host>.json` in place of `socle/hosts/`, and no hardware.

## The layers

A value comes from the first layer that sets it:

1. this machine's layer (`socle/hosts/<host>.json`);
2. your layer (`socle/system.json`);
3. the template, then the templates that it extends;
4. NixOS and its modules.

A layer is JSON: the template's name and the values of NixOS options. For example:

```json
{
  "socle": 1,
  "template": "socle#family-desktop",
  "values": {
    "services": {"printing": {"enable": false}},
    "socle": {"packages": {"krita": true, "vlc": false}}
  }
}
```

Apps are a set (`"vlc": false` removes the template's VLC). A list adds to what NixOS has. `custom/*.nix` files are
ordinary NixOS modules: they set options as any configuration does, below Socle's layers unless they use
`lib.mkForce`.

## Build it without Socle

The folder is a plain flake. Each command works on it:

```sh
sudo nixos-rebuild switch --flake /etc/socle#<host>
nh os switch /etc/socle
nix build /etc/socle#nixosConfigurations.<host>.config.system.build.toplevel
```

The base sets nh to the folder, so `nh os switch` alone is enough. A version applied this way shows in Socle's history
as "Made outside socle", because Socle did not record it.

## The history

Each version that Socle keeps is a commit of the folder, with the review's words as its message. `git log` in the
folder is the history of the system's settings. Each version of the system holds the hash of the layers that made it
(`/run/current-system/socle-revision`), which joins it to its commit.

## Who can write it

`/etc/socle` belongs to root and the group `wheel`: an administrator changes the layers without root. Only the switch
needs root: Socle's helper does it, through polkit.

## The base

Every system that Socle installs has these, each one a setting on **Start and power**:

- Determinate Nix, with its telemetry off.
- nh, set to `/etc/socle`, and its weekly clean of the versions beyond the kept count.
- nix-output-monitor, for builds in a terminal.
- bootvine: the start and the shutdown show systemd's jobs as a tree, and ask the disk's passphrase.
- systemd-boot, NetworkManager, the firewall, store optimisation.
