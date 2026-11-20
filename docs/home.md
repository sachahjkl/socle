# A home on any Linux

On a Linux that is not NixOS, Socle manages your **home**: your own apps, your shell and your tools, through
[Home Manager](https://github.com/nix-community/home-manager). Nothing outside your account changes, and no
administrator's password is asked.

## What you need

- [Nix](https://nixos.org/download/) with flakes on. We recommend [Determinate Nix](https://docs.determinate.systems/).
- A graphical session (Wayland or X11) for the window.

On NixOS, a home works too: start Socle with `socle --home`.

## 1. Open Socle

```sh
nix run github:sachahjkl/socle
```

On a Linux that is not NixOS, Socle opens your home. The first time, it offers two templates:

- **A developer's terminal**: Git and GitHub's tool, a prompt (Starship), direnv, fzf, zoxide, ripgrep, fd, bat, jq,
  just.
- **Just my apps**: your apps and Socle, nothing else.

Click **Start my home**. Socle writes `~/.config/socle`, a folder in git. Nothing changes yet.

## 2. Change it

- **Apps**: add any package of Nixpkgs. The search covers all of them.
- **Shell**: bash, zsh or fish, a prompt, direnv, fzf, zoxide.
- **Development**: Git, GitHub's tool, Helix, Neovim, VS Code.
- **Tools**: nh and nix-output-monitor.
- **All settings**: every option of Home Manager, with search.

## 3. Apply

Click **Review and apply**, then **Prepare and apply**. A home applies at once: there is no trial and no countdown,
because a broken home does not take the screen or the network away. Each version stays in **History**, and **Go back
to it** runs one again.

Your apps are then in `~/.nix-profile/bin`. Open a new terminal, or log in again, to see them on your path.

## Without the window

The folder is a plain Home Manager flake, and the home has Home Manager's command. From a terminal:

```sh
home-manager switch --flake ~/.config/socle
```

It takes the home of `<you>@<this computer>`, the one that Socle wrote.

## On macOS

Not yet: Socle's program runs on Linux only. See the [roadmap](https://github.com/sachahjkl/socle/blob/master/ROADMAP.md).
