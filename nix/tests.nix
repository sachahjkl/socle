# The switch, tested for real in a virtual machine (src/md/README.md, "The first tests": the revert). Opt-in: it boots a
# NixOS and takes minutes. nix build .#tests.switch
#
# The machine is socle's test folder (tests/vm) without a desktop, managed by socle: /etc/socle is written at its
# start. In it, a person's change (the hello package) is built with nix from /etc/socle; `socle helper try` runs it;
# nobody keeps it, and systemd's timer goes back by itself; then a second try is kept, and becomes the default. The
# changed system is built on the host first: the machine has no network, and finds it in its store.
{
  self,
  inputs,
  lib,
  pkgs,
  socleLib,
}: let
  # (the test bed's folder, with the test driver's link in its code: tests/switch/custom/test.nix)
  root = ../tests/switch;
  layer = values: {
    socle = 1;
    template = "socle#minimal";
    inherit values;
  };
  common = {
    socle = {
      people.demo = {
        description = "Demo";
        admin = true;
      };
      # (the test machine has no network: no Determinate daemon to log in, no start screen to watch)
      base = {
        determinate = false;
        bootvine = false;
      };
    };
  };
  modulesOf = values:
    (socleLib.configuration {
      inputs = inputs // {socle = self;};
      inherit root;
      system = layer values;
    })
    .socleModules
    .socle-vm;
  changedValues = lib.recursiveUpdate common {socle.packages.hello = true;};
  changed =
    (inputs.nixpkgs.lib.nixosSystem {
      modules = modulesOf changedValues;
    })
    .config
    .system
    .build
    .toplevel;
  sources = let
    go = input: [input.outPath] ++ lib.concatMap go (builtins.attrValues (input.inputs or {}));
  in
    lib.unique (lib.concatMap go [self inputs.nixpkgs]);
  flake = builtins.toFile "flake.nix" ''
    {
      inputs = {
        nixpkgs.url = "path:${inputs.nixpkgs}";
        socle = {
          url = "path:${self}";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };
      outputs = inputs: inputs.socle.lib.configuration {
        inherit inputs;
        root = ./.;
      };
    }
  '';
  systemJSON = builtins.toFile "system.json" (builtins.toJSON (layer common));
  changedJSON = builtins.toFile "system.json" (builtins.toJSON (layer changedValues));
in {
  switch = pkgs.testers.runNixOSTest {
    name = "socle-switch";
    # (the machine's Nixpkgs is its own, as on a real system: its apps accept their licences one by one)
    node.pkgsReadOnly = false;
    nodes.machine = {
      imports = modulesOf common;
      virtualisation = {
        additionalPaths = sources ++ [changed];
        writableStore = true;
      };
      nix.settings.substituters = lib.mkForce [];
      # (the framework names its machine; the folder's systems keep their own name)
      networking.hostName = lib.mkForce "machine";
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed(
          "mkdir -p /etc/socle && cp -r --no-preserve=mode ${root}/. /etc/socle/",
          "cp --no-preserve=mode ${flake} /etc/socle/flake.nix",
          "cp --no-preserve=mode ${systemJSON} /etc/socle/socle/system.json",
          "cd /etc/socle && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm start",
      )
      before = machine.succeed("readlink -f /run/current-system").strip()

      # the person's change, built from the folder as the window does
      machine.succeed("cp --no-preserve=mode ${changedJSON} /etc/socle/socle/system.json && cd /etc/socle && git add -A")
      path = machine.succeed(
          "nix --extra-experimental-features 'nix-command flakes' build --offline --no-link --print-out-paths "
          "/etc/socle#nixosConfigurations.socle-vm.config.system.build.toplevel"
      ).strip()
      assert path == "${changed}", f"the folder built {path}, not the host's ${changed}"

      # a try that nobody keeps: the timer goes back by itself
      machine.succeed(f"socle helper try {path}")
      machine.succeed("test \"$(readlink -f /run/current-system)\" = " + path)
      machine.succeed("command -v hello")
      machine.wait_until_succeeds(f"test \"$(readlink -f /run/current-system)\" = {before}", timeout=180)
      machine.fail("test -e /run/socle/state.json")
      machine.succeed(f"test \"$(readlink -f /nix/var/nix/profiles/system)\" = {before}")

      # a try that is kept: the default from now on
      machine.succeed(f"socle helper try {path}")
      machine.succeed("socle helper keep")
      machine.succeed(f"test \"$(readlink -f /nix/var/nix/profiles/system)\" = {path}")
      machine.succeed(f"test \"$(readlink -f /run/current-system)\" = {path}")
      machine.fail("systemctl is-active socle-revert.timer")

      # a try then a revert by hand
      machine.succeed(f"socle helper try {before}")
      machine.succeed("socle helper revert")
      machine.succeed(f"test \"$(readlink -f /run/current-system)\" = {path}")
    '';
  };
}
