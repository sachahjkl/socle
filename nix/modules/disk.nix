# The machine's disk, as the installer wrote it in the machine's layer (src/md/features/installer.md): one whole disk,
# encrypted or not, becomes disko's configuration. Its file systems then come from disko, not from a hardware report.
{
  config,
  lib,
  ...
}: let
  cfg = config.socle.disk;
  # (btrfs: its subvolumes share the disk's space, and a later version can take snapshots of them)
  subvolumes = {
    type = "btrfs";
    extraArgs = ["-f"];
    subvolumes = let
      at = mountpoint: {
        inherit mountpoint;
        mountOptions = ["compress=zstd" "noatime"];
      };
    in {
      "/root" = at "/";
      "/home" = at "/home";
      "/nix" = at "/nix";
    };
  };
in {
  options.socle.disk = {
    device = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The whole disk the system is installed on (a path in /dev/disk/by-id when it has one). Empty: the file systems come from the hardware report.";
    };
    encrypt = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "The disk is encrypted: its passphrase is asked at each start.";
    };
  };

  config = lib.mkIf (cfg.device != "") {
    disko.devices.disk.main = {
      type = "disk";
      inherit (cfg) device;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };
          system = {
            size = "100%";
            content =
              if cfg.encrypt
              then {
                type = "luks";
                name = "system";
                # (read at the format only, from the helper's file; at each start the passphrase is asked)
                passwordFile = "/run/socle/disk.key";
                settings.allowDiscards = true;
                content = subvolumes;
              }
              else subvolumes;
          };
        };
      };
    };
    # (memory compressed in place of a swap partition: nothing to size at the install)
    zramSwap.enable = lib.mkDefault true;
  };
}
