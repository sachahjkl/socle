# socle's images and base

socle is also a NixOS distribution with opinions: live images that boot into socle's installer, and a base that every
system installed by socle starts from.

## The images

socle's flake builds live images (`nixosConfigurations.image-*`, an ISO each):

- **Desktop**: a graphical session that opens socle's installer at start ([installer.md](installer.md)).
- **Minimal**: a console, with `socle install` in the terminal for servers and remote installs over SSH.

Each image carries the same base as an installed system, so what a person tries on the live image is what they get.
The CI builds the images at each release and publishes them beside the program.

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
