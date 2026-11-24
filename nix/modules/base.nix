# The base of every system that socle installs (src/md/features/images.md): each part a setting.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.socle.base;
in {
  options.socle.base = {
    enable = lib.mkEnableOption "socle's base: the choices every new system needs" // {default = true;};
    determinate = lib.mkEnableOption "Determinate Nix in place of Nix from Nixpkgs" // {default = true;};
    nh = lib.mkEnableOption "nh, set to socle's folder, for the terminal" // {default = true;};
    outputMonitor = lib.mkEnableOption "nix-output-monitor: builds shown as a tree in the terminal" // {default = true;};
    bootvine = lib.mkEnableOption "bootvine: the start and the shutdown show systemd's jobs as a tree" // {default = true;};
    keepVersions = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 10;
      description = "The versions of the system that stay to go back to; older ones are removed each week.";
    };
  };

  config = lib.mkMerge [
    {determinate.enable = lib.mkDefault (cfg.enable && cfg.determinate);}
    (lib.mkIf (cfg.enable && cfg.determinate) {
      # (no telemetry, no crash reports sent)
      systemd.services.nix-daemon.environment = {
        DETSYS_IDS_TELEMETRY = "disabled";
        NIX_SENTRY_ENDPOINT = "";
      };
    })
    (lib.mkIf cfg.enable {
      nix = {
        settings.experimental-features = ["nix-command" "flakes"];
        optimise.automatic = lib.mkDefault true;
      };
      programs.nh = lib.mkIf cfg.nh {
        enable = true;
        flake = "/etc/socle";
        clean = {
          enable = true;
          dates = "weekly";
          extraArgs = "--keep ${toString cfg.keepVersions}";
        };
      };
      environment.systemPackages = lib.optional cfg.outputMonitor pkgs.nix-output-monitor ++ [pkgs.git];
      services.bootvine.enable = lib.mkDefault cfg.bootvine;
      boot = {
        # (bootvine takes the console and asks the disk's passphrase: Plymouth would cover it)
        plymouth.enable = lib.mkIf cfg.bootvine (lib.mkForce false);
        initrd.systemd.enable = lib.mkDefault true;
        loader.systemd-boot.enable = lib.mkDefault true;
        loader.efi.canTouchEfiVariables = lib.mkDefault true;
      };
      networking.networkmanager.enable = lib.mkDefault true;
      networking.firewall.enable = lib.mkDefault true;
      documentation = {
        man.cache.enable = lib.mkDefault false;
        nixos.enable = lib.mkDefault false;
      };
      time.timeZone = lib.mkDefault "Europe/Paris";
      i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
      # (one keyboard for the desktop and the console: the passphrase typed at the start is the one chosen; region.md)
      console.useXkbConfig = lib.mkDefault true;
      system.stateVersion = lib.mkDefault "26.05";
    })
  ];
}
