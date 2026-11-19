# The base of every home that socle manages: the tools a terminal needs to see Nix work, each one a setting
# (src/md/features/images.md, "The base"; a home has no boot, no daemon and no store to clean of its own).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.socle.base;
in {
  options.socle.base = {
    enable = lib.mkEnableOption "socle's base: the tools every home needs" // {default = true;};
    nh = lib.mkEnableOption "nh, for the terminal" // {default = true;};
    outputMonitor = lib.mkEnableOption "nix-output-monitor: builds shown as a tree in the terminal" // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional cfg.nh pkgs.nh ++ lib.optional cfg.outputMonitor pkgs.nix-output-monitor;
    # (Home Manager's own command, for a person who prefers the terminal: home-manager switch --flake ~/.config/socle)
    programs.home-manager.enable = lib.mkDefault true;
    socle.ui.pages.base = {
      title = "Tools";
      icon = "power";
      order = 30;
      options = ["socle.base.nh" "socle.base.outputMonitor"];
    };
  };
}
