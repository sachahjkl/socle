# The switch test's machine (nix/tests.nix): every version it switches to keeps the test driver's link to it.
{modulesPath, ...}: {
  imports = [(modulesPath + "/testing/test-instrumentation.nix")];
}
