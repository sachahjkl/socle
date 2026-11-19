# Roadmap

## Now

- **Your own template.** Turn the current system or home into a template, extend another one, export it as a git
  repository that anyone can start from. [Templates](src/md/data/templates.md).

## Next

- **The installer's other disks.** Install beside another system on a disk that it shares, and on a machine that
  starts in legacy BIOS mode. [The installer](src/md/features/installer.md).
- **A home without Nix, and on macOS.** A program that runs without Nix, which installs Nix (Determinate's installer)
  and then starts a home; the same on macOS. [Targets](src/md/data/targets.md).

## Later

- **Several machines.** One configuration for several hosts, and a deployment to another machine over SSH.

## Maybe

- **The hub.** An online index of shared templates, searched from the gallery. Two ways are open: an index file in a
  git repository that takes additions by pull request, or a service with accounts, ratings and screenshots. Both wait
  until the template format is stable and real templates exist.
- **Adopt an existing configuration.** Take a flake that a person wrote as the lowest layer and add socle's layers on
  top. It waits for the managed format to be stable; the risk is a value that the person's Nix and socle both set at
  the same priority.
- **An offline install.** The Minimal template's whole system on its image, for a machine with no network. It waits
  for a reason to make the image twice as large.
