# The apps of a system: for every person, in the system's packages (nix/shared/apps.nix declares them).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.socle;
  chosen = import ../shared/chosen.nix {inherit lib pkgs cfg;};
  # (an app that NixOS sets up as a program, not as a package: its module does what the package alone cannot)
  programs = ["steam"];
  # (Steam's licence covers the parts its module installs)
  unfree = chosen.unfree {steam = ["steam" "steam-original" "steam-unwrapped" "steam-run"];};
in {
  imports = [../shared/apps.nix];
  config = {
    environment.systemPackages = chosen.packages programs;
    programs.steam.enable = lib.mkIf (cfg.packages.steam or false) true;
    nixpkgs.config.allowUnfreePredicate = lib.mkIf (unfree != []) (p: builtins.elem (lib.getName p) unfree);
  };
}
