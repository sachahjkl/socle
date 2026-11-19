# Changelog

All notable changes to socle are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the versions follow [semantic versioning](https://semver.org/).

## [0.3.0] - 2026-11-19 20:43

### Added
- **The installer**: `socle install` opens a window that installs socle on a whole disk: language, keyboard, time zone, Wi-Fi, the disk (encrypted or not), the first account, the system to start from, a review that names the disk it erases, then the install with its progress. `socle install --disk=...` does the same in a terminal.
- **socle's live images**: a Desktop image that starts straight into the installer, and a Minimal image with a console for servers and installs over SSH. Both carry socle's base: Determinate Nix, nh and nix-output-monitor.

### Changed
- **Free space keeps as many versions as the weekly clean**: the history's button keeps the number of versions that Start and power sets, ten unless you change it.

### Fixed
- **Take a machine over that starts with GRUB**: socle keeps the boot loader that the machine has, on the disk it starts from, in place of its base's systemd-boot.

## [0.2.0] - 2026-11-19 15:48

### Added
- **Search everything**: Apps searches every package of the locked Nixpkgs, and All settings searches every option of the system.
- **Free space**: the history removes the versions beyond the newest ten and collects what they used; the window says how much space came back.
- **Try socle in a virtual machine**: `nix run github:sachahjkl/socle#vm` starts a NixOS that socle manages, its window open; every change you apply there is real, inside the machine.
- **Take a machine over**: on a NixOS that socle does not manage, socle offers to start from a template; it writes its folder with this machine's hardware and people, and nothing changes until you apply.
- **More pages**: People (accounts and administrators), Hardware, Sound, Network, Printing, Gaming, Sharing and Start and power, made from NixOS's own options; Templates to start from another system; Updates to move the sources forward with the same review.
- **socle's library, templates and base**: a managed folder's flake calls `socle.lib.configuration`; five templates (Family desktop, Gaming machine, Developer workstation, Home server, Minimal); every system gets Determinate Nix, nh, nix-output-monitor and bootvine, each one a setting.
- **socle drives a real system**: it reads `/etc/socle` (or `--folder`), evaluates it with Nix, and shows its real values, apps with the versions of the locked Nixpkgs, people and versions. Each change is saved at once and checked by an evaluation; Review and apply builds the system with its progress, tries it for 60 seconds through an administrator's password, and keeps it, goes back, or starts it at the next boot; the folder records each kept version in git.

## [0.1.0] - 2026-11-19 12:53

### Added
- **The window, on a demo system**: the overview, apps to add and remove, the desktop's settings, the bar of changes, the review, the try with its countdown and the keep, the history, the templates and every option. It drives no Nix yet.
- **The site and the film**: socle.froment.software presents socle with a film of its window, driven as a person uses it.
- **The design of socle**: what it does and how, in the intent (src/md), with ten mockups of its screens and its mark.

[0.3.0]: https://github.com/sachahjkl/socle/releases/tag/v0.3.0
[0.2.0]: https://github.com/sachahjkl/socle/releases/tag/v0.2.0
[0.1.0]: https://github.com/sachahjkl/socle/releases/tag/v0.1.0
