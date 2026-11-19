# The apps of a home: the person's own packages (nix/shared/apps.nix declares them).
{
  config,
  lib,
  pkgs,
  ...
}: let
  chosen = import ../shared/chosen.nix {
    inherit lib pkgs;
    cfg = config.socle;
  };
  unfree = chosen.unfree {};
in {
  imports = [../shared/apps.nix];
  config = {
    home.packages = chosen.packages [];
    nixpkgs.config.allowUnfreePredicate = lib.mkIf (unfree != []) (p: builtins.elem (lib.getName p) unfree);
  };
}
