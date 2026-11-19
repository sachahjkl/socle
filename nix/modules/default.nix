# socle's NixOS module: part of every system that socle manages (src/md/README.md). The features under `socle.*`, the
# base, socle itself and its helper.
{
  self,
  inputs,
}: {
  imports = [
    inputs.determinate.nixosModules.default
    inputs.bootvine.nixosModules.default
    inputs.disko.nixosModules.disko
    ../shared/identity.nix
    ../shared/ui.nix
    ./disk.nix
    ./pages.nix
    ./base.nix
    ./desktop.nix
    ./apps.nix
    ./people.nix
    ./program.nix
  ];

  config._module.args.socleSelf = self;
}
