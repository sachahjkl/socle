# The installer

socle installs a machine from one of socle's live images ([images.md](images.md)), or from any NixOS live image where
`nix run github:sachahjkl/socle -- install` starts it. The installer writes the same folder as any socle system: the
installed machine has socle and socle's base from its first start.

## The steps

1. **Language and keyboard.** They go in the machine's layer (`i18n`, `console`, the desktop's keymap).
2. **Disk.** The whole disk, with or without encryption. socle writes a disk layer; the library turns it into a
   [disko](https://github.com/nix-community/disko) configuration. A disk shared with another system is not in the
   first version.
3. **Person.** Name, login, password. The password is hashed on the machine (yescrypt) and only the hash goes in the
   machine's layer.
4. **Template.** The gallery. The review shows what the template sets.
5. **Review.** The disk that will be erased (model, size, its current partitions), the template, the person.
6. **Install.** disko formats and mounts; `nixos-facter` writes `hosts/<host>/facter.json`; socle writes
   `/mnt/etc/socle` and its first commit; `nixos-install --flake /mnt/etc/socle#<host>` installs.
7. **First start.** socle opens on the Overview, with the template's pages.

## The point of no return

Every step can go back until "Install" erases the disk. The button names the disk ("Erase Samsung SSD 990, 2 TB, and
install"). After that, a failure shows the log and offers to start the install again from the formatted disk.

## Choices

- **nixos-facter over nixos-generate-config.** Its report is JSON, so the hardware is data like the rest; the
  `hardware.facter` module of NixOS reads it.
- **The network is needed.** The image does not carry the closures of every template. An offline install of the
  "Minimal" template only is possible later.
