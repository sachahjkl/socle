# Changelog

All notable changes to socle are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the versions follow [semantic versioning](https://semver.org/).

## [0.11.0] - 2026-11-28 00:23

### Added
- **Faster first frame**: the window shows its first frame drawn on the CPU while the graphics device starts, so Socle opens sooner.

### Fixed
- **Dropdown lists and debug panels**: dropdown rows are no longer cut at fractional display scales, and the debug window opens in release builds with its acts, toggles, tabs and header buttons aligned inside the window.

## [0.10.0] - 2026-11-27 17:47

### Added
- **Debug panels**: Ctrl+Alt+Shift+D opens socle's state beside the window: the folder's read, the draft and its evaluation, the apply and its build log, the search indexes, the installer. Their acts reach the hard cases from the demo: a read, an evaluation, a build or an install that fails, a long build log, an index read again.

## [0.9.2] - 2026-11-26 21:23

### Fixed
- **Searches no longer blink**: while a search of the time zones or of every package looks for the letters just typed, the last results stay on screen, and the page below them no longer jumps at each key.

## [0.9.1] - 2026-11-26 20:39

### Fixed
- **The light or dark look of the desktop**: on a desktop that states no preference (GNOME by default), the window follows its look again, and the marks of its checkboxes stay readable in every theme.

## [0.9.0] - 2026-11-24 11:22

### Added
- **A Region page**: the time zone, the language and the keyboard change after the install. A time zone is found by its city, its country or its offset (paris, new york, utc+9), and shows its time now; the installer searches its time zone the same way.

## [0.8.0] - 2026-11-21 10:13

### Added
- **Lower latency on Linux**: during an animation or a drag, each frame starts as late as it can and still reaches the next refresh, so it shows the newest input.

### Changed
- **Every menu filters what is typed**: a field at the top of a menu keeps the items that match.

## [0.7.0] - 2026-11-20 10:58

### Added
- **A build's details**: while a new version is prepared, Details unfolds nix's own lines above the bar (what is downloaded, what is built, what it prints), and after a failure they stay there to read.

### Changed
- **Screen lock after any delay**: the screen lock takes any delay, in hours and minutes, in a field typed part by part or set on wheels that open with a click; a switch turns it off.

## [0.6.0] - 2026-11-20 07:57

### Added
- **The documentation**: the site has a Docs section, with search: getting started in a virtual machine, installing a computer step by step, taking over a NixOS, a home on any Linux, everyday use, templates, the folder, every command, and what to do when something fails. The home page starts with the four ways in.

### Fixed
- **nix run github:sachahjkl/socle works**: the package no longer needs the toolkit as a git submodule, which a github: address does not fetch.
- **An install that stops can start again**: the disk is unmounted and closed after a failure, so Back to the review and a new try work.

## [0.5.0] - 2026-11-20 06:30

### Added
- **Your own templates**: Templates saves the applied system as a template, without its people or their accounts, in a git repository of its own that you can push anywhere; a link such as github:owner/repository#name starts a system from someone's template. The gallery shows every template of your sources, and says when one runs its own Nix.

### Fixed
- **Taking a machine over and installing work where git signs commits**: socle's own commits are never signed, so a signing key that root or the session does not have no longer stops them.
- **Discard undoes everything**: it also brings back the sources and the template links of the last applied version.
- **Notes and warnings read on one line**: the mark of a warning stands beside its title, not on a line of its own.

## [0.4.0] - 2026-11-19 21:37

### Added
- **A home on any Linux with Nix**: socle manages your own apps, shell and tools through Home Manager, in ~/.config/socle, with the same pages, review and history as a system, and no administrator. On a system that is not NixOS it starts there; on NixOS, `socle --home` opens it. Two templates start one: A developer's terminal, and Just my apps.

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

[0.11.0]: https://github.com/sachahjkl/socle/releases/tag/v0.11.0
[0.10.0]: https://github.com/sachahjkl/socle/releases/tag/v0.10.0
[0.9.2]: https://github.com/sachahjkl/socle/releases/tag/v0.9.2
[0.9.1]: https://github.com/sachahjkl/socle/releases/tag/v0.9.1
[0.9.0]: https://github.com/sachahjkl/socle/releases/tag/v0.9.0
[0.8.0]: https://github.com/sachahjkl/socle/releases/tag/v0.8.0
[0.7.0]: https://github.com/sachahjkl/socle/releases/tag/v0.7.0
[0.6.0]: https://github.com/sachahjkl/socle/releases/tag/v0.6.0
[0.5.0]: https://github.com/sachahjkl/socle/releases/tag/v0.5.0
[0.4.0]: https://github.com/sachahjkl/socle/releases/tag/v0.4.0
[0.3.0]: https://github.com/sachahjkl/socle/releases/tag/v0.3.0
[0.2.0]: https://github.com/sachahjkl/socle/releases/tag/v0.2.0
[0.1.0]: https://github.com/sachahjkl/socle/releases/tag/v0.1.0
