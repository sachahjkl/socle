# The switch test's machine (nix/tests.nix): every version it switches to keeps the test driver's link to it.
{
  lib,
  modulesPath,
  ...
}: {
  imports = [(modulesPath + "/testing/test-instrumentation.nix")];

  # (inside the machine, Nixpkgs is a path: no date, no revision; the host's has both. The same words on both sides, so
  # the system built inside is the one built on the host, found in the machine's store)
  # (the test framework's own values, nixos/lib/testing/nixos-test-base.nix: the same, so both definitions agree)
  system.nixos = {
    label = lib.mkForce "test";
    versionSuffix = lib.mkForce "test";
    revision = lib.mkForce "constant-nixos-revision";
  };
}
