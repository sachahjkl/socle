# The switch and the install, tested for real in virtual machines (src/md/README.md, "The first tests"). Opt-in: each
# boots a NixOS and takes minutes. nix build .#tests.switch, nix build .#tests.install
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
  images,
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
  # (a derivation, not builtins.toFile: with lazy trees, the sources it names are virtual until a derivation needs them)
  flake = pkgs.writeText "flake.nix" ''
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

  # The install: the folder of tests/install (a person's choices, as the installer writes them) installed by the
  # helper on an empty disk, then that disk started. Built on the host first, as the switch's system is.
  installRoot = ../tests/install;
  installed =
    (socleLib.configuration {
      inputs = inputs // {socle = self;};
      root = installRoot;
    })
    .nixosConfigurations
    .socle-test;
  # The Desktop image, with the test driver's link, started from its ISO on UEFI as a computer starts it
  # (nixos/tests/boot.nix)
  imageISO = (images.desktopWith [({modulesPath, ...}: {imports = [(modulesPath + "/testing/test-instrumentation.nix")];})]).config.system.build.isoImage;
  imageStart = let
    qemu =
      (import (inputs.nixpkgs + "/nixos/lib/qemu-common.nix") {
        inherit lib;
        inherit (pkgs) stdenv;
      }).qemuBinary
      pkgs.qemu_test;
  in
    lib.concatStringsSep " " [
      qemu
      "-m 4096 -smp 2 -vga virtio"
      "-cdrom ${imageISO}/iso/${imageISO.name}"
      "-drive if=pflash,format=raw,unit=0,readonly=on,file=${pkgs.OVMF.firmware}"
      "-drive if=pflash,format=raw,unit=1,readonly=on,file=${pkgs.OVMF.variables}"
    ];

  # (both machines are one: the installer writes the disk that the target starts from, as nixos/tests/installer.nix)
  installDisk = {
    virtualisation = {
      diskImage = "./target.qcow2";
      # (the boot partition takes 1 GiB, the system the rest)
      diskSize = 12 * 1024;
      useEFIBoot = true;
      # (an evaluation of NixOS, and the copy of socle's source into the store, at once)
      memorySize = 6144;
      cores = 4;
    };
  };
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
      # (a test's machine cannot switch unless asked: the try goes back to it)
      system.switch.enable = true;
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

      # the helper's words when it refuses: the test's log shows them
      def helper(verb):
          rc, out = machine.execute(f"socle helper {verb} 2>&1")
          print(out)
          assert rc == 0, f"socle helper {verb}: {out}"

      # a try that nobody keeps: the timer goes back by itself
      helper(f"try {path}")
      machine.succeed("test \"$(readlink -f /run/current-system)\" = " + path)
      machine.succeed("command -v hello")
      try:
          machine.wait_until_succeeds(f"test \"$(readlink -f /run/current-system)\" = {before}", timeout=180)
      except Exception:
          print(machine.execute("systemctl list-timers --all 2>&1; journalctl -u 'socle-revert*' -u 'socle-activate*' --no-pager 2>&1 | tail -60")[1])
          raise
      machine.fail("test -e /run/socle/state.json")
      # (the try never became the default; a test's machine may have no profile at all)
      machine.fail(f"test \"$(readlink -f /nix/var/nix/profiles/system)\" = {path}")

      # a try that is kept: the default from now on
      helper(f"try {path}")
      helper("keep")
      machine.succeed(f"test \"$(readlink -f /nix/var/nix/profiles/system)\" = {path}")
      machine.succeed(f"test \"$(readlink -f /run/current-system)\" = {path}")
      machine.fail("systemctl list-timers --no-legend | grep -q socle-revert")

      # a try then a revert by hand
      helper(f"try {before}")
      helper("revert")
      machine.succeed(f"test \"$(readlink -f /run/current-system)\" = {path}")

      # free space: the newest version stays, the running one with it
      machine.fail("socle helper collect 0")
      helper("collect 1")
      machine.succeed("test \"$(nix-env --list-generations -p /nix/var/nix/profiles/system | wc -l)\" = 1")
      machine.succeed(f"test -e {path}")
    '';
  };

  # The Desktop image starts its installer: greetd, the kiosk session of sway, socle's window in it.
  image = pkgs.testers.runNixOSTest {
    name = "socle-image";
    nodes = {};
    testScript = ''
      machine = create_machine("${imageStart}")
      # (a machine of create_machine outlives a failed script: it is stopped whatever happens)
      try:
          machine.start()
          machine.wait_for_unit("greetd.service")
          machine.succeed("test -d /sys/firmware/efi")
          machine.wait_until_succeeds("pgrep -f 'socle install'", timeout=180)
          # (the window is in sway's tree: it opened, on the image's own graphics)
          machine.wait_until_succeeds(
              "SWAYSOCK=$(ls /run/user/1000/sway-ipc.*.sock) swaymsg -t get_tree | grep -q '\"app_id\": \"socle\"'",
              timeout=180,
          )
          machine.screenshot("installer")
          # (the live user runs the helper without a password, polkit's rule for socle's action: the helper itself
          # answers, and refuses a folder that is not one)
          rc, out = machine.execute("su nixos -c 'pkexec --disable-internal-agent ${self.packages.${pkgs.stdenv.hostPlatform.system}.socle}/bin/socle helper install /nonexistent' 2>&1")
          print(out)
          assert "is not a folder that socle wrote" in out, "the helper did not run for the live user"
      finally:
          machine.crash()
    '';
  };

  install = pkgs.testers.runNixOSTest {
    name = "socle-install";
    # (the installation profile sets Nixpkgs' options, which a read-only Nixpkgs refuses)
    node.pkgsReadOnly = false;
    nodes = {
      installer = {modulesPath, ...}: {
        imports = [
          installDisk
          (modulesPath + "/profiles/installation-device.nix")
          (modulesPath + "/../tests/common/auto-format-root-device.nix")
        ];
        # (the installer runs from a small second disk: the target's disk is /dev/vda while it installs and after)
        virtualisation = {
          emptyDiskImages = [2048];
          rootDevice = "/dev/vdb";
          # (made at the first start, by systemd's stage 1 or by the common module's script)
          fileSystems."/".autoFormat = true;
          additionalPaths =
            sources
            ++ [
              installed.config.system.build.toplevel
              installed.config.system.build.diskoScript
            ];
        };
        environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.socle pkgs.git];
        nix.settings = {
          experimental-features = ["nix-command" "flakes"];
          substituters = lib.mkForce [];
        };
        hardware.enableAllFirmware = lib.mkForce false;
      };
      target = {
        imports = [installDisk];
        virtualisation = {
          useBootLoader = true;
          useDefaultFilesystems = false;
          efi.keepVariables = false;
          # (never used: the target starts from what the installer wrote)
          fileSystems."/" = {
            device = "/dev/disk/by-label/this-is-not-real";
            fsType = "ext4";
          };
        };
      };
    };
    testScript = ''
      installer.start()
      installer.wait_for_unit("multi-user.target")
      installer.succeed(
          "mkdir -p /tmp/folder && cp -r --no-preserve=mode ${installRoot}/. /tmp/folder/",
          "cp --no-preserve=mode ${flake} /tmp/folder/flake.nix",
          # (Nix 2.34 writes socle's "submodules" into the lock of a path: input, then refuses to read it: the folder's
          # lock without it. A real folder names socle by git+https, which takes it)
          "nix flake lock path:/tmp/folder && sed -i '/\"submodules\": true,/d' /tmp/folder/flake.lock",
      )

      # (nix's messages kept, its progress left out)
      rc, out = installer.execute("socle helper install /tmp/folder 2>&1 | grep -v '^@nix {\"action\":\"\\(start\\|stop\\|result\\)\"' ; exit ''${PIPESTATUS[0]}")
      print(out)
      assert rc == 0, "socle helper install failed"
      for step in ["Check", "Disk", "Folder", "Hardware", "Build", "Install", "Done"]:
          assert f"@socle {step}" in out, f"the install did not say {step}"

      installer.succeed(
          "git -C /mnt/etc/socle log --format=%s | grep -qx 'Install from socle#minimal'",
          "test -z \"$(git -C /mnt/etc/socle status --porcelain)\"",
      )
      installer.succeed("umount -R /mnt", "sync")
      installer.shutdown()

      # the installed disk, started by its own boot loader
      target.state_dir = installer.state_dir
      target.start()
      target.wait_for_unit("multi-user.target")
      target.succeed(
          "test -e /boot/loader/loader.conf",
          "test \"$(readlink -f /run/current-system)\" = ${installed.config.system.build.toplevel}",
          "test \"$(findmnt -no FSTYPE /)\" = btrfs",
          "id -nG ada | grep -qw wheel",
          "test \"$(stat -c %G /etc/socle)\" = wheel",
          "git -C /etc/socle log --format=%s | grep -qx 'Install from socle#minimal'",
      )

      # a takeover of this machine: its boot loader found on its boot partition (systemd-boot: the base's, nothing
      # written), its hardware read, its people kept
      target.succeed(
          "mv /etc/socle /root/installed && mkdir /etc/socle",
          "socle helper init socle#minimal 2>&1",
          "test -e /etc/socle/hosts/socle-test/hardware.nix",
          "! grep -q grub /etc/socle/socle/hosts/socle-test.json",
          "grep -q '\"ada\"' /etc/socle/socle/system.json",
      )
    '';
  };
}
