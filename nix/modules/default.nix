# socle's NixOS module: part of every system that socle manages (src/md/README.md). The features under `socle.*`, the
# base, socle itself and its helper.
{
  self,
  inputs,
}: {lib, ...}: {
  imports = [
    inputs.determinate.nixosModules.default
    inputs.bootvine.nixosModules.default
    ./ui.nix
    ./pages.nix
    ./base.nix
    ./desktop.nix
    ./apps.nix
    ./people.nix
    ./program.nix
  ];

  options.socle = {
    revision = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The hash of the layers that made this system: the history joins versions and commits by it.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The host's name in the folder (socle/hosts/<host>.json).";
    };
    template = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The template the system starts from, as <input>#<name>.";
    };
  };

  config._module.args.socleSelf = self;
}
