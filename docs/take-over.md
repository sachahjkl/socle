# Take over your NixOS

On a NixOS that you already use, Socle can take the machine over: from then on, the system comes from Socle's folder,
`/etc/socle`, and not from `/etc/nixos`.

> **What Socle keeps, and what it does not.** Socle keeps the machine's hardware, its boot loader, its accounts and
> their passwords. It does not read your `configuration.nix`: the services, packages and settings in it are not in the
> new system until you add them, on Socle's pages or as Nix files in `/etc/socle/custom/` (below). Keep a copy of
> `/etc/nixos`.

## What you need

- NixOS, started with systemd-boot or GRUB. The new system is NixOS 26.05, Socle's release: an older machine is
  updated by the first apply. Its `system.stateVersion` stays the one it had.
- An account in the group `wheel` (an administrator).
- Nix with flakes on. NixOS's own Nix needs `--extra-experimental-features 'nix-command flakes'` after `nix`.

## 1. Open Socle

```sh
nix run github:sachahjkl/socle
```

Socle sees that it does not manage the machine, and offers to start from a template.

## 2. Choose a template and take over

1. Choose what to start from: Family desktop, Gaming machine, Developer workstation, Home server or Minimal.
2. Turn on **I understand: socle manages this machine from now on**.
3. Click **Take this machine over**. Your administrator's password is asked.

Socle writes `/etc/socle`:

- the template that you chose, and the machine's accounts (`socle/system.json`);
- the machine's name, its NixOS release and its boot loader (`socle/hosts/<host>.json`);
- its hardware, read by `nixos-generate-config` (`hosts/<host>/hardware.nix`);
- a git history, with a first commit.

Nothing changes in the running system yet.

## 3. Bring over what you need

Look at the pages: Apps, Desktop, Network, Sharing. Turn on what your old configuration had. For anything that no page
shows, copy it from your old configuration into a file of `/etc/socle/custom/`. Socle imports every `.nix` file there
as it is, and never rewrites it:

```nix
# /etc/socle/custom/old.nix: what /etc/nixos/configuration.nix had, that no page of Socle's shows
{pkgs, ...}: {
  services.syncthing = {
    enable = true;
    user = "ada";
  };
  environment.systemPackages = [pkgs.htop];
}
```

The **All settings** page searches every option of NixOS, and says who sets each one: this machine, you, the template,
or NixOS.

## 4. Apply

Click **Review and apply**. Socle builds the new system and tries it. Click **Keep** within 60 seconds, or it goes back
by itself. Apply **At the next start** instead when the desktop changes: the session would close.

After the first apply, Socle is installed in the system, in the apps and as `socle` in a terminal.

## Undo

The versions from before the takeover stay in the boot menu and in Socle's **History**, marked "Made outside socle".
**Go back to it** runs one again. To leave Socle for good, rebuild from your old folder:

```sh
sudo nixos-rebuild switch --flake /etc/nixos   # or without --flake, for a configuration.nix
sudo rm -r /etc/socle
```
