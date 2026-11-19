# The install test's machine (nix/tests.nix): a virtual machine of the test driver, which brings its own hardware so
# the helper does not read it (helper_install.odin), and keeps the driver's link once installed.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/testing/test-instrumentation.nix")
  ];

  # (inside the installer, Nixpkgs is a path: no date, no revision; the host's has both. The same words on both sides,
  # so the system built inside is the one built on the host, found in the installer's store)
  system.nixos = {
    label = lib.mkForce "test";
    versionSuffix = lib.mkForce "test";
    revision = lib.mkForce "constant-nixos-revision";
  };
}
