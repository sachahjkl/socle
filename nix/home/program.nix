# socle itself in a home: the window in the person's packages, and the layers' hash in each version of the home, which
# the history reads (src/md/features/apply.md). A home needs no helper: the person applies it.
{
  config,
  lib,
  pkgs,
  socleSelf,
  ...
}: let
  package = config.socle.package;
in {
  options.socle.package = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = socleSelf.packages.${pkgs.stdenv.hostPlatform.system}.socle or null;
    description = "socle's program; null: none.";
  };

  config = {
    home.packages = lib.optional (package != null) package;
    home.extraBuilderCommands = ''
      printf '%s' '${config.socle.revision}' > $out/socle-revision
    '';
  };
}
