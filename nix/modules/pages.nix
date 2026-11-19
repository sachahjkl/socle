# The pages whose settings are NixOS's own options: the window makes each page from these declarations (type, values,
# description), so a page never drifts from the module it shows (src/md/features/features.md).
_: let
  page = title: icon: order: options: {inherit title icon order options;};
in {
  config.socle.ui.pages = {
    hardware = page "Hardware" "cpu" 11 [
      "hardware.bluetooth.enable"
      "hardware.graphics.enable32Bit"
      "services.fwupd.enable"
      "services.fstrim.enable"
    ];
    sound = page "Sound" "volume-2" 12 [
      "services.pipewire.enable"
      "services.pipewire.pulse.enable"
      "services.pipewire.jack.enable"
    ];
    network = page "Network" "wifi" 13 [
      "networking.networkmanager.enable"
      "networking.firewall.enable"
      "services.avahi.enable"
      "services.tailscale.enable"
    ];
    printing = page "Printing" "printer" 14 [
      "services.printing.enable"
      "services.ipp-usb.enable"
      "hardware.sane.enable"
    ];
    gaming = page "Gaming" "gamepad-2" 15 [
      "programs.gamemode.enable"
      "hardware.steam-hardware.enable"
      "hardware.xone.enable"
    ];
    sharing = page "Sharing" "share-2" 16 [
      "services.openssh.enable"
      "services.avahi.publish.enable"
      "services.jellyfin.enable"
    ];
    power = page "Start and power" "power" 17 [
      "services.power-profiles-daemon.enable"
      "services.thermald.enable"
      "socle.base.keepVersions"
      "socle.base.bootvine"
      "socle.base.determinate"
      "socle.base.nh"
      "socle.base.outputMonitor"
    ];
  };
}
