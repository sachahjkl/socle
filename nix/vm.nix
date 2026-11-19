# The test bed: a NixOS that socle manages, in a virtual machine (`nix run .#vm`). It starts from tests/vm; at its first
# start it writes /etc/socle from that folder, its flake pointing at this socle and this Nixpkgs, which are in its
# store: the window inside evaluates, builds and switches the virtual machine for real, with nothing to download to
# evaluate. The switch test of the intent (src/md/README.md, "The first tests") runs here.
{
  self,
  inputs,
  lib,
  socleLib,
}: let
  root = ../tests/vm;

  # every source the folder's flake needs, with their own inputs: in the machine's store, they need no network
  sources = let
    go = input: [input.outPath] ++ lib.concatMap go (builtins.attrValues (input.inputs or {}));
  in
    lib.unique (lib.concatMap go [self inputs.nixpkgs]);

  flake = builtins.toFile "flake.nix" ''
    {
      description = "The test machine's system, managed by socle.";
      inputs = {
        nixpkgs.url = "path:${inputs.nixpkgs}";
        socle = {
          url = "path:${self}";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
      outputs = inputs: inputs.socle.lib.configuration {
        inherit inputs;
        root = ./.;
      };
    }
  '';

  seed = {
    pkgs,
    config,
    ...
  }: {
    virtualisation.additionalPaths = sources;
    systemd.services.socle-seed = {
      description = "socle's folder of the test machine, written once";
      wantedBy = ["multi-user.target"];
      before = ["display-manager.service"];
      after = ["nix-daemon.service"];
      unitConfig.ConditionPathExists = "!/etc/socle/flake.nix";
      serviceConfig.Type = "oneshot";
      path = [pkgs.git pkgs.coreutils config.nix.package];
      environment.HOME = "/root";
      script = ''
        mkdir -p /etc/socle
        cp -r --no-preserve=mode ${root}/. /etc/socle/
        cp --no-preserve=mode ${flake} /etc/socle/flake.nix
        cd /etc/socle
        git init -q --shared=group
        nix --extra-experimental-features 'nix-command flakes' flake lock --offline || true
        git add -A
        git -c user.name=socle -c user.email=socle@localhost commit -q -m "Start from Family desktop"
        chgrp -R wheel /etc/socle
        chmod -R g+rwX /etc/socle
      '';
    };
    # the window opens with the session
    environment.etc."xdg/autostart/socle.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Socle
      Exec=socle
      Icon=socle
    '';
  };

  base =
    (socleLib.configuration {
      inputs = inputs // {socle = self;};
      inherit root;
    })
    .nixosConfigurations
    .socle-vm;
in
  base.extendModules {modules = [seed];}
