# Socle documentation

Socle runs a whole NixOS computer from one window. You start from a ready-made system, change any setting on a page,
review the change, and go back in one step when it does not suit you. You never write Nix. Under the window, the
configuration is a plain flake that builds without Socle.

## Start here

| You have | Do this | Page |
|---|---|---|
| Ten minutes and no spare computer | Run Socle in a virtual machine | [Getting started](getting-started.md) |
| A computer to install | Start it from Socle's image | [Install a computer](install.md) |
| A NixOS that you already use | Let Socle take it over | [Take over your NixOS](take-over.md) |
| Another Linux with Nix | Manage your own apps and shell | [A home on any Linux](home.md) |

## What Socle manages

- **A system**: the whole NixOS machine. Its apps, people, desktop, hardware, network, printing, sharing and start.
  An administrator applies a change, and Socle tries it for 60 seconds before it keeps it.
- **A home**: one person's apps, shell and tools, through Home Manager, on any Linux with Nix. No administrator is
  needed, and a change applies at once.

## Learn more

- [Everyday use](using.md): the pages, the review, the try and the keep, the history, the updates.
- [Templates](templates.md): start from one, save your own, share it.
- [The folder](folder.md): what Socle writes, and how to build it without Socle.
- [Commands](commands.md): every command and flag.
- [When something fails](troubleshooting.md).
