# Getting started

This page runs Socle in a virtual machine on your computer. Every change that you apply there is real, but it stays
inside the machine. Nothing on your computer changes.

## What you need

- Linux with [Nix](https://nixos.org/download/) and flakes. We recommend
  [Determinate Nix](https://docs.determinate.systems/), which has flakes on.
- KVM: a processor with virtualisation turned on in the firmware.
- 6 GB of free memory and 30 GB of free disk space.

If your Nix does not have flakes on, add `--extra-experimental-features 'nix-command flakes'` after `nix` in each
command of this page.

## 1. Start the virtual machine

```sh
mkdir socle-try && cd socle-try
nix run github:sachahjkl/socle#vm
```

The first start downloads and builds for a few minutes. A window opens with a desktop: the machine opens the session
of `demo` by itself, and Socle's window opens in it. When Socle asks for an administrator's password, it is `socle`. The disk of the machine is the file `socle-vm.qcow2` in the
current folder: delete it to start again from zero.

## 2. Look around

The **Overview** shows the version that runs, the age of the software catalogue, and a tile for each page. The pages
on the left change the system: **Apps**, **People**, **Desktop**, **Hardware**, **Sound**, and more.

## 3. Make a change

1. Open **Apps**, find **OBS Studio** and click **Add**.
2. Open **Desktop**, and turn **Dark look** off.

The bar at the bottom of the window counts your changes. Socle saves each change at once and checks that the system
still evaluates. A red dot in the bar says that it does not, and the review says why.

## 4. Apply it

1. Click **Review and apply**. The review lists each change in words.
2. Keep **Now, on trial**, and click **Prepare and apply**. The bar shows the download and the build.
3. The new version runs. A dialog counts down from 60 seconds: click **Keep**.

If you do not click **Keep**, the system goes back to the version before by itself. A change that breaks the screen
or the network thus repairs itself.

## 5. Go back

Open **History**. Each version is there, with the changes that made it. Click **Go back to it** on the version before:
it runs again, with the same try and keep.

## Next

- [Install a computer](install.md) with Socle's image.
- [Take over your NixOS](take-over.md), if you already use one.
- [Everyday use](using.md) tells each part of the window.
