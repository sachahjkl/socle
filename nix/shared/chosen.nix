# The apps that socle.packages turns on, as packages, and the licences accepted: what each target's apps module reads
# (nix/shared/apps.nix). A function, not options: the window evaluates socle.* to JSON, which has no functions.
{
  lib,
  pkgs,
  cfg,
}: let
  on = set: builtins.attrNames (lib.filterAttrs (_: v: v) set);
  resolve = name: lib.attrByPath (lib.splitString "." name) (throw "socle: Nixpkgs has no package ${name}") pkgs;
in {
  # the chosen apps, but those that `except` names (a target sets them up otherwise)
  packages = except: map resolve (builtins.filter (n: !(builtins.elem n except)) (on cfg.packages));
  # the names of the accepted packages whose licence is not free, each with the parts that `parts` says it brings
  unfree = parts: lib.concatMap (n: parts.${n} or [n]) (on cfg.unfree);
}
