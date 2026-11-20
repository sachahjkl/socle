# Install a computer

Socle's image starts a computer from a USB stick and installs NixOS on its disk, with Socle and its base: Determinate
Nix, nh and nix-output-monitor.

> **The install erases one whole disk.** Keep a copy of what is on it. Installing beside another system on the same
> disk is not possible yet.

## What you need

- A computer that starts in **UEFI** mode. A computer from after 2012 does. Legacy BIOS mode is not supported yet.
- A disk of 16 GB or more, which the install erases.
- The network, by cable or Wi-Fi: the install downloads the system.
- A USB stick of 4 GB or more.

## 1. Download an image

Take the latest version from the [releases](https://github.com/sachahjkl/socle/releases):

| Image | For | Size |
|---|---|---|
| `socle-<version>-desktop-x86_64-linux.iso` | A computer with a screen: the installer opens in a window | 1.8 GB |
| `socle-<version>-minimal-x86_64-linux.iso` | A server, or an install over SSH: a console | 1.7 GB |

Check the download against `SHA256SUMS`, from the same release:

```sh
sha256sum -c SHA256SUMS --ignore-missing
```

## 2. Write it to a USB stick

On Linux, find the stick's name with `lsblk`, then write the image to the whole stick (not to a partition). This
erases the stick:

```sh
sudo dd if=socle-<version>-desktop-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

On Windows or macOS, use [balenaEtcher](https://etcher.balena.io/) or [Rufus](https://rufus.ie/) (in DD mode).

## 3. Start the computer from the stick

Put the stick in, start the computer, and open its boot menu (often F12, F10, F8 or Esc at the start). Choose the
stick's UEFI entry. If the computer refuses the stick, turn **Secure Boot** off in the firmware's settings.

The Desktop image opens the installer full screen.

## 4. The installer's steps

1. **Language.** The language, the keyboard and the time zone. The keyboard changes at once, so what you type next
   uses it. The same keyboard is used at each start, where the disk's passphrase is typed.
2. **Network.** This step shows only when the computer is not online: choose a Wi-Fi network and type its password.
3. **Disk.** Choose the disk. A disk that holds the install medium, or is too small, cannot be chosen. Turn
   **Encrypt the disk** on to protect it with a passphrase of 8 characters or more. Nobody can read the disk without
   the passphrase, and nobody can recover it for you.
4. **You.** Your name, your login (lowercase letters and digits), your password, and the computer's name. Your account
   administers the computer.
5. **System.** What the computer is for: Family desktop, Gaming machine, Developer workstation, Home server or
   Minimal. Every setting can change later.
6. **Review.** The disk that is erased, and every choice. Nothing has changed yet. The red button names the disk:
   **Erase \<disk\>, \<size\>, and install**.
7. **Install.** Socle formats the disk, reads the hardware, downloads and builds the system, and installs it. This
   takes from 10 to 40 minutes, most of it the download. The computer can be left alone.

When the install ends, click **Restart**, and take the stick out while the computer restarts.

## 5. The first start

If the disk is encrypted, type its passphrase. Log in with your account. Socle is in the apps: open it to change the
system. [Everyday use](using.md) tells the rest.

## The Minimal image, or an install from a terminal

The Minimal image starts to a console, logged in as `nixos`. The same install runs from flags:

```sh
lsblk -o NAME,SIZE,MODEL,ID-LINK      # find the disk
sudo socle install \
  --disk=/dev/disk/by-id/<the disk> \
  --template=socle#home-server \
  --host=myserver --login=ada --name="Ada Lovelace" \
  --keyboard=us --locale=en_US.UTF-8 --zone=Europe/Paris \
  --yes
```

Without `--yes`, Socle says which disk it would erase and stops. It asks the password itself (with `mkpasswd`), and
the passphrase when you add `--encrypt`. [Commands](commands.md) lists every flag.

To install over SSH, set a password for `nixos` with `passwd` on the computer's console, then connect with
`ssh nixos@<address>`.

From any other NixOS live image, the same installer runs with:

```sh
nix run github:sachahjkl/socle -- install
```

## What the install writes

- The disk: a 1 GB boot partition, then btrfs with the subvolumes `/`, `/home` and `/nix` (in LUKS when encrypted).
- `/etc/socle`: the configuration, in git, with its first commit "Install from \<template\>". [The folder](folder.md)
  tells what is in it.
- The boot loader: systemd-boot.

If the install stops, the window shows what went wrong. Click **Back to the review** to try again: the disk is erased
again from the start. [When something fails](troubleshooting.md) lists the usual causes.
