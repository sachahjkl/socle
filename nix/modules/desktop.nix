# The desktop: what people see after they log in. One choice sets the display manager, the desktop and their settings.
{
  config,
  lib,
  ...
}: let
  cfg = config.socle.desktop;
  on = cfg.environment != "none";
  seconds = cfg.lockAfter * 60;
in {
  options.socle.desktop = {
    environment = lib.mkOption {
      type = lib.types.enum ["plasma" "gnome" "cosmic" "none"];
      default = "none";
      description = "The desktop that people see after they log in.";
    };
    dark = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Windows, menus and panels in dark colours.";
    };
    autoLogin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Opens one person's session at start, with no password.";
      };
      user = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Whose session opens by itself.";
      };
    };
    lockAfter = lib.mkOption {
      type = lib.types.ints.between 0 1439;
      default = 5;
      description = "Locks the session once the screen goes off, after this many minutes; 0: never.";
    };
  };

  config = lib.mkMerge [
    {
      socle.ui.pages.desktop = {
        title = "Desktop";
        icon = "monitor";
        order = 10;
        options = ["socle.desktop.environment" "socle.desktop.dark" "socle.desktop.autoLogin.enable" "socle.desktop.autoLogin.user" "socle.desktop.lockAfter"];
      };
    }
    (lib.mkIf on {
      services.pipewire = {
        enable = lib.mkDefault true;
        pulse.enable = lib.mkDefault true;
      };
      hardware.graphics.enable = lib.mkDefault true;
      services.displayManager.autoLogin = lib.mkIf (cfg.autoLogin.enable && cfg.autoLogin.user != "") {
        enable = true;
        inherit (cfg.autoLogin) user;
      };
    })
    (lib.mkIf (cfg.environment == "plasma") {
      services.desktopManager.plasma6.enable = true;
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      environment.etc."xdg/kdeglobals".text = ''
        [KDE]
        LookAndFeelPackage=${
          if cfg.dark
          then "org.kde.breezedark.desktop"
          else "org.kde.breeze.desktop"
        }
      '';
      environment.etc."xdg/kscreenlockerrc".text = ''
        [Daemon]
        Autolock=${lib.boolToString (seconds > 0)}
        Timeout=${toString (seconds / 60)}
      '';
    })
    (lib.mkIf (cfg.environment == "gnome") {
      services.desktopManager.gnome.enable = true;
      services.displayManager.gdm.enable = true;
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/gnome/desktop/interface".color-scheme =
              if cfg.dark
              then "prefer-dark"
              else "default";
            "org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 seconds;
            "org/gnome/desktop/screensaver".lock-enabled = seconds > 0;
          };
        }
      ];
    })
    (lib.mkIf (cfg.environment == "cosmic") {
      services.desktopManager.cosmic.enable = true;
      services.displayManager.cosmic-greeter.enable = true;
    })
  ];
}
