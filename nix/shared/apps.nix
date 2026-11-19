# The apps, for a system and for a home alike: a set keyed by the package's attribute, so a higher layer can remove
# what a lower one added (src/md/features/apps.md). A licence that is not free is accepted package by package. Each
# target writes the chosen packages where it keeps them (nix/modules/apps.nix, nix/home/apps.nix), with chosen.nix.
{lib, ...}: {
  options.socle = {
    packages = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "The apps, by their attribute in Nixpkgs.";
    };
    unfree = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "The packages whose licence is not free that the person accepted, one by one.";
    };
  };

  config.socle.ui.pages.apps = {
    title = "Apps";
    icon = "package";
    order = 1;
    options = ["socle.packages" "socle.unfree"];
  };
}
