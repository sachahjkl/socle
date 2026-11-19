# The test machine is a virtual machine: its system is one, so socle switches it as it would a real one. The person's
# code of this folder (custom/): socle imports it as it is.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];

  virtualisation = {
    memorySize = 6144;
    cores = 4;
    diskSize = 30 * 1024;
    qemu.options = ["-vga virtio"];
  };

  # (the virtual machine starts its kernel directly: no boot loader to install, keep only sets the profile)
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub.enable = lib.mkForce false;
}
