# The installer

socle installs a machine from one of socle's live images ([images.md](images.md)), or from any NixOS live image where
`nix run github:sachahjkl/socle -- install` starts it. The installer writes the same folder as any socle system: the
installed machine has socle and socle's base from its first start.

## The plan is a folder

The window (or `socle install` in a terminal) writes, without root, the folder as it will be on the disk:
`flake.nix`, `socle/system.json` and `socle/hosts/<host>.json` (`install.odin`, `plan_write`). Everything that the
install needs is in it, the disk included: the machine's layer names the disk (`socle.disk`), the language, the
keyboard, the time zone and the password's hash. The helper's one verb, `socle helper install <folder>`, takes that
folder and nothing else.

- What the person reviewed is what the helper installs: there is no second description of the machine to keep in
  step.
- A test can give its own folder, with its own hardware, and know in advance the exact system that results
  (`nix build .#tests.install`).
- The system layer holds what could be shared and what the window changes later (the template, the person, the
  region); the machine's layer holds what belongs to this machine alone (its release, its disk, the password's hash).
  The window never writes the machine's layer: a value there could not be changed from a page (region.md).
- The disk's passphrase is never in the folder (it is committed): it waits beside it, in `<folder>.key`, readable by
  its owner only. The helper moves it to `/run/socle/disk.key`, which disko reads at the format, and removes it.

## The steps

1. **Language, keyboard, time zone.** One keyboard for the desktop and the console (`console.useXkbConfig`): the
   passphrase typed at each start is typed on the keyboard chosen here. The language gives its time zone; the person
   searches another, as on the Region page (region.md).
2. **Disk.** One whole disk, encrypted or not. `nix/modules/disk.nix` turns `socle.disk` into disko's
   configuration: a 1 GiB boot partition, then btrfs with the subvolumes `/`, `/home` and `/nix` (LUKS around it when
   encrypted). A disk shared with another system is not in the first version.
3. **Person.** Name, login, password. `mkpasswd` hashes the password (yescrypt), on its standard input.
4. **Template.** The gallery.
5. **Review.** The disk that will be erased (model, size), the template, the person.
6. **Install.** The helper's steps, each said on its standard error as `@socle <Step>`, with nix's log between:
   - Check: UEFI (the base starts with systemd-boot), a whole disk with nothing mounted, `/mnt` free.
   - Disk: disko's script, built from the folder as a `path:` flake, erases and mounts.
   - Folder: the folder copied to `/mnt/etc/socle`.
   - Hardware: `nixos-facter` writes `hosts/<host>/facter.json`, unless the folder brings its own hardware.
   - The folder is recorded in git, its lock written once, by its git form, and committed with it.
   - Build: the folder's sources archived into the new disk's store, then the system built there.
   - Install: `nixos-install --system` writes the boot loader.
7. **First start.** socle opens on the Overview, with the template's pages.

## The point of no return

Every step can go back until "Install" erases the disk. The button names the disk ("Erase Samsung SSD 990, 2 TB, and
install"). After that, a failure shows nix's or the program's last words and offers to start the install again.

## Subtle points

- The build goes into the new disk's store (`--store /mnt`), not the live system's: a live image's store is in
  memory, and a desktop's system does not fit there.
- It takes from the live system's store through the daemon (`daemon?trusted=1`): as root, `auto` and `local` open a
  local store as the new disk's is, and nix takes nothing from them. `always-allow-substitutes` is on: NixOS's small
  derivations say `allowSubstitutes = false`, and building them needs a whole stdenv.
- The sources go into the new disk's store first (`nix flake archive`): the build there fetches nothing again, and the
  installed machine can build its system with no network.
- The disk's script is built from a `path:` flake with no lock written: a lock of a `path:` flake does not suit the
  same folder in git.
- A build says millions of lines: each line's temporary memory is freed with it (`nix_log_line`).

## Choices

- **nixos-facter over nixos-generate-config.** Its report is JSON, so the hardware is data like the rest; the
  `hardware.facter` module of NixOS reads it.
- **The network is needed.** The image does not carry the closures of every template. An offline install of the
  "Minimal" template only is possible later.
- **One folder, not a description and a folder.** A plan as its own JSON, turned into a folder by the helper, would be
  a second schema of the machine, and the review would show what the helper reads, not what it installs.
