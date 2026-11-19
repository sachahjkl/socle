# Roadmap

## Now

- **The managed configuration.** socle's Nix library reads the layers and the flake that socle writes, and the result
  builds with plain `nixos-rebuild`, without socle. [The configuration](src/md/data/configuration.md).
- **The overview.** A window that shows the running system: its generation, its template, its pending changes, the
  state of its updates. [The window](src/md/features/window.md).
- **Apply and go back.** The draft, the review of what changes, the build with its progress, the switch through the
  helper, the history of the generations and a return to any of them. [Apply](src/md/features/apply.md),
  [the helper](src/md/infrastructure/helper.md).

## Next

- **Apps.** Search the packages of the pinned Nixpkgs, add and remove them, for the whole system or for one person.
  [Apps](src/md/features/apps.md).
- **The pages of settings.** Desktop, users, network, sound, printing, gaming, sharing: each page is a form made from
  the options of a feature. [Features](src/md/features/features.md).
- **All settings.** Search every NixOS option of the system, see its value and the layer that sets it, change it.
  [All settings](src/md/features/all-settings.md).
- **Templates.** Start from a ready-made system, follow its updates, replace any of its choices.
  [Templates](src/md/data/templates.md).
- **Updates.** Move Nixpkgs, socle's library and the templates forward, with the same review as any change.
- **The base.** Determinate Nix, nh and nix-output-monitor in every system that socle installs, each one a setting.
  [Images and base](src/md/features/images.md).
- **A home on any system.** A person's apps, shell and settings through Home Manager, on any Linux with Nix or on
  macOS; socle installs Nix if it is missing. [Targets](src/md/data/targets.md).

## Later

- **The installer and socle's images.** Live images that boot into socle's installer: the disk, the first person,
  the template, the install, the first start. [The installer](src/md/features/installer.md),
  [images](src/md/features/images.md).
- **Your own template.** Turn the current system into a template, extend another one, export it as a git repository
  that anyone can start from. [Templates](src/md/data/templates.md).
- **Several machines.** One configuration for several hosts, and a deployment to another machine over SSH.

## Maybe

- **The hub.** An online index of shared templates, searched from the gallery. Two ways are open: an index file in a
  git repository that takes additions by pull request, or a service with accounts, ratings and screenshots. Both wait
  until the template format is stable and real templates exist.
- **Adopt an existing configuration.** Take a flake that a person wrote as the lowest layer and add socle's layers on
  top. It waits for the managed format to be stable; the risk is a value that the person's Nix and socle both set at
  the same priority.
