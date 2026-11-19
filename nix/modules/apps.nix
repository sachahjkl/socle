# The apps of every person: a set keyed by the package's attribute, so a higher layer can remove what a lower one
# added (src/md/features/apps.md). A licence that is not free is accepted package by package.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.socle;
  chosen = set: builtins.attrNames (lib.filterAttrs (_: on: on) set);
  # (an app that NixOS sets up as a program, not as a package: its module does what the package alone cannot)
  programs = ["steam"];
  resolve = name: lib.attrByPath (lib.splitString "." name) (throw "socle: Nixpkgs has no package ${name}") pkgs;
  # (Steam's licence covers the parts its module installs)
  unfreeParts = {steam = ["steam" "steam-original" "steam-unwrapped" "steam-run"];};
  unfree = lib.concatMap (n: unfreeParts.${n} or [n]) (chosen cfg.unfree);
in {
  options.socle = {
    packages = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "The apps for every person, by their attribute in Nixpkgs.";
    };
    unfree = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "The packages whose licence is not free that the person accepted, one by one.";
    };
  };

  config = {
    socle.ui.pages.apps = {
      title = "Apps";
      icon = "package";
      order = 1;
      options = ["socle.packages" "socle.unfree"];
    };
    environment.systemPackages = map resolve (builtins.filter (n: !(builtins.elem n programs)) (chosen cfg.packages));
    programs.steam.enable = lib.mkIf (cfg.packages.steam or false) true;
    nixpkgs.config.allowUnfreePredicate = lib.mkIf (unfree != []) (p: builtins.elem (lib.getName p) unfree);
  };
}
