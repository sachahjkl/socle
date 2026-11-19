# The people of the machine: an account each, its apps, whether it administers the machine.
{
  config,
  lib,
  pkgs,
  ...
}: let
  resolve = name: lib.attrByPath (lib.splitString "." name) (throw "socle: Nixpkgs has no package ${name}") pkgs;
in {
  options.socle.people = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "The person's full name.";
        };
        admin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "The person administers the machine: applies changes, installs for everyone.";
        };
        hashedPassword = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "The password's hash (yescrypt); only the machine's layer holds it.";
        };
        packages = lib.mkOption {
          type = lib.types.attrsOf lib.types.bool;
          default = {};
          description = "The person's own apps.";
        };
      };
    });
    default = {};
    description = "The people of the machine, by their login.";
  };

  config = {
    socle.ui.pages.people = {
      title = "People";
      icon = "users";
      order = 2;
      options = ["socle.people"];
    };
    users.users =
      lib.mapAttrs (_: p: {
        isNormalUser = true;
        inherit (p) description;
        extraGroups = ["networkmanager" "video" "audio"] ++ lib.optional p.admin "wheel";
        hashedPassword = lib.mkIf (p.hashedPassword != null) p.hashedPassword;
        packages = map resolve (builtins.attrNames (lib.filterAttrs (_: on: on) p.packages));
      })
      config.socle.people;
  };
}
