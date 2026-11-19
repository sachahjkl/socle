# socle's images and base

socle is also a NixOS distribution with opinions: live images that boot into socle's installer, and a base that every
system installed by socle starts from.

## The images

socle's flake builds live images (`nix/images.nix`, `nix build .#iso-desktop` and `.#iso-minimal`), on NixOS's own
live image:

- **Desktop**: greetd starts a kiosk session of sway, and sway opens `socle install` full screen
  ([installer.md](installer.md)). When the window closes, the session ends and greetd opens it again.
- **Minimal**: a console. Its login screen says how to run `socle install --disk=...`, for servers and installs over
  SSH.

Each image carries socle's base (Determinate Nix, nh, nix-output-monitor) and what the installer runs (git, mkpasswd,
nixos-facter), and NetworkManager for the Wi-Fi. bootvine is off on the images: they start from their own boot
loader. The CI builds the images at each release and publishes them beside the program.

### Choices

- **sway, not cage.** The installer's keyboard choice changes the live session's keyboard at once (`swaymsg input`):
  what a person types in the installer is what the installed machine reads. cage cannot change it.
- **No password for the live user.** A polkit rule lets the user `nixos` run socle's helper without one, as sudo does
  on every NixOS live image.
- **Under 2 GiB each** (a release's file on GitHub): the kiosk has no speech service and no portal, and socle's
  program does not keep its compiler's paths (the package removes them; `disallowedReferences` keeps them out).

### Tests

- `nix build .#tests.image` starts the Desktop ISO on UEFI, waits for socle's window in sway's tree, takes a
  screenshot, and runs the helper as the live user.
- `nix build .#tests.install` installs a folder on an empty disk and starts the result (installer.md).

## The base

The base is the feature `socle.base`, on in every template of socle. A person can turn each part off on the page
"Start and power".

- **Determinate Nix** in place of Nix from Nixpkgs: flakes on, a daemon that recovers by itself, fast lazy trees.
  Its telemetry is off.
- **nh**, set to `/etc/socle`: a person who prefers the terminal runs `nh os switch` on the same folder. nh's
  cleaning is the same as socle's "Free space", with the same limits.
- **nix-output-monitor**: the terminal shows a build as a tree of what downloads and what builds. `socle apply` in a
  terminal pipes its build's log through it.
- **bootvine** ([codeberg.org/wvhulle/bootvine](https://codeberg.org/wvhulle/bootvine)) in place of Plymouth: the
  start and the shutdown show a live tree of systemd's jobs, from the initrd to the desktop, and bootvine asks the
  disk's passphrase itself. A start that fails says which unit and why, where a splash screen hides it.
- Automatic store optimisation, a weekly clean of old versions beyond the last ten, the documentation caches off.

## Why opinions

A person who chose socle chose not to decide these things. The base removes the choices that every new NixOS user
makes alone and often gets wrong: flakes off, a store that grows without end, no readable build output, a start that
hides its errors behind a splash. Each part
stays a setting, so an expert can turn it off.

## The terminal

socle has a command line (gt:cli) with the same pipeline as the window, for SSH and for scripts: `socle status`,
`socle apply [--boot]`, `socle back <version>`, `socle install`. In a terminal, the countdown of a try is a prompt
("Keep? [y/N] 42 s").
