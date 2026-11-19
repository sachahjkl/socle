# Roadmap

## Now

- **The installer and socle's images.** Live images that boot into socle's installer: the disk, the first person,
  the template, the install, the first start. [The installer](src/md/features/installer.md),
  [images](src/md/features/images.md).

## Next

- **A home on any system.** A person's apps, shell and settings through Home Manager, on any Linux with Nix or on
  macOS; socle installs Nix if it is missing. [Targets](src/md/data/targets.md).

## Later

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
