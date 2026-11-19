# socle's live images (src/md/features/images.md): a NixOS live system with socle's installer, and socle's base as an
# installed system has it. nix build .#iso-desktop, nix build .#iso-minimal
#
#   desktop  the installer's window, full screen in a kiosk session of sway (its keyboard follows the installer's)
#   minimal  a console: `socle install --disk=...` in a terminal or over SSH
{
  self,
  inputs,
  lib,
}: let
  system = "x86_64-linux";

  # What both images have: the live system, socle and what its installer runs, the base's tools.
  common = {
    config,
    pkgs,
    modulesPath,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
      self.nixosModules.socle
    ];
    socle.base = {
      # (the live system starts from the image's own boot loader, and shows its console)
      bootvine = false;
    };
    # (the image starts from its own boot loader)
    boot.loader.systemd-boot.enable = lib.mkForce false;
    networking = {
      hostName = "socle-live";
      networkmanager.enable = true;
      wireless.enable = lib.mkForce false;
    };
    users.users.nixos.extraGroups = ["networkmanager"];
    environment.systemPackages = with pkgs; [git mkpasswd nixos-facter nh nix-output-monitor];
    # (the live user has no password: socle's helper runs for it without one, as sudo does)
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "software.froment.socle.apply" && subject.user == "nixos") {
          return polkit.Result.YES;
        }
      });
    '';
    image.baseName = lib.mkForce "socle-${config.socle.package.version}-${config.socle.image}-${pkgs.stdenv.hostPlatform.system}";
    isoImage = {
      appendToMenuLabel = " socle";
      volumeID = lib.mkForce "SOCLE";
    };
  };

  desktop = {
    pkgs,
    config,
    ...
  }: let
    swayConfig = pkgs.writeText "socle-sway" ''
      default_border none
      output * bg #0b1020 solid_color
      for_window [app_id=".*"] fullscreen enable
      # (the installer closed: the session ends, and greetd opens it again)
      exec "${config.socle.package}/bin/socle install; ${pkgs.sway}/bin/swaymsg exit"
    '';
  in {
    socle.image = "desktop";
    programs.sway = {
      enable = true;
      extraPackages = [];
    };
    hardware.graphics.enable = true;
    # (a kiosk of one window: no speech service with its voices, no portal with GTK; the image fits a release's file)
    services.speechd.enable = lib.mkForce false;
    xdg.portal.enable = lib.mkForce false;
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.sway}/bin/sway --config ${swayConfig}";
        user = "nixos";
      };
    };
  };

  minimal = {
    socle.image = "minimal";
    services.getty.helpLine = lib.mkForce ''

      socle installs a system on this computer:
        lsblk                                          lists the disks
        sudo socle install --disk=/dev/disk/by-id/... --template=socle#minimal --host=<name> --login=<you> --yes
      The templates: socle#family-desktop, socle#gaming, socle#developer, socle#home-server, socle#minimal.
    '';
  };

  # (the image's name in its file name: an option, so the common module reads it)
  named = {
    options.socle.image = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "The live image's name.";
    };
  };

  image = modules:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [named common] ++ modules;
    };
in {
  image-desktop = image [desktop];
  image-minimal = image [minimal];
  # (the Desktop image with more modules: the test's driver link, nix/tests.nix)
  desktopWith = modules: image ([desktop] ++ modules);
}
