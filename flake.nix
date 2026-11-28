{
  description = "socle: your whole system in one window: start from a ready-made system, change any setting, go back in one step.";

  inputs = {
    self.submodules = true;
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605";
    git-hooks = {
      url = "https://flakehub.com/f/cachix/git-hooks.nix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # socle's base (src/md/features/images.md): Determinate Nix, and bootvine's start screen
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
    bootvine = {
      url = "git+https://codeberg.org/wvhulle/bootvine";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # the toolkit the program is built on: the same commit as the ext/gui_toolkit submodule (socletool check says so). An
    # input, not the submodule, for the package: a github: flake comes without its submodules
    gui_toolkit = {
      url = "github:sachahjkl/gui_toolkit/v0.370.0";
      flake = false;
    };
    # a home on any system (src/md/data/targets.md): Home Manager on its own, NixOS or not
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.2605";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # the installer's disk (src/md/features/installer.md): a machine layer's disk becomes disko's configuration
    disko = {
      url = "https://flakehub.com/f/nix-community/disko/1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    git-hooks,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    inherit (pkgs) lib;

    # the library a managed folder's flake calls (src/md/data/configuration.md)
    socleLib = import ./nix/lib.nix {
      inherit lib;
      socle = self;
    };

    # socle's live images (nix/images.nix)
    images = import ./nix/images.nix {inherit self inputs lib;};

    wgpu = pkgs.fetchurl {
      url = "https://github.com/gfx-rs/wgpu-native/releases/download/v29.0.1.1/wgpu-linux-x86_64-release.zip";
      sha256 = "95a4d90c071005a98d03eab348beaa6b07e16eb00d1dcdb9f8348f75eb97ec5a";
    };

    odin = pkgs.stdenv.mkDerivation {
      pname = "odin";
      version = "dev-2026-11a";
      src = pkgs.fetchurl {
        url = "https://github.com/odin-lang/Odin/releases/download/dev-2026-11a/odin-linux-amd64-dev-2026-11a.tar.gz";
        sha256 = "65c9f6e97d6f8a30930e151f270ce5aeaa98fe8b2ba49fe067394e2af04f7618";
      };
      nativeBuildInputs = [pkgs.makeWrapper pkgs.unzip];
      dontBuild = true;
      dontPatchELF = true;
      installPhase = ''
        mkdir -p $out/lib/odin $out/bin
        cp -r . $out/lib/odin
        dest=$out/lib/odin/vendor/wgpu/lib/wgpu-linux-x86_64-release
        mkdir -p $dest
        unzip -qo ${wgpu} -d $dest
        echo 29.0.1.1 > $dest/VERSION
        makeWrapper $out/lib/odin/odin $out/bin/odin --set-default ODIN_ROOT $out/lib/odin/ --prefix PATH : ${lib.makeBinPath [pkgs.clang pkgs.lld]}
      '';
    };

    runtime = with pkgs; [
      vulkan-loader
      mesa
      libxkbcommon
      wayland
      libx11
      libxcb
      libxcb-cursor
      fontconfig
      freetype
      dbus
      curl # (gt:http opens libcurl at run time)
    ];

    # APP_VERSION of src/version.odin
    version = let
      line = lib.findFirst (lib.hasPrefix "APP_VERSION ::") "" (lib.splitString "\n" (builtins.readFile ./src/version.odin));
    in
      builtins.head (builtins.match ''APP_VERSION :: "([^"]+)".*'' line);

    # socle, built from this tree as the release is: socletool build release.
    socle = pkgs.stdenv.mkDerivation {
      pname = "socle";
      inherit version;
      src = lib.fileset.toSource {
        root = ./.;
        # (tests/install and tests/template stay: unit tests of the program load them; the toolkit is the input's)
        fileset = lib.fileset.difference ./. (lib.fileset.unions (map lib.fileset.maybeMissing [./site ./build ./docs ./tests/demo ./tests/sample ./tests/bare ./tests/switch ./tests/vm ./tests/home ./ext/gui_toolkit]));
      };
      # the toolkit where the build looks for it
      postUnpack = ''
        mkdir -p $sourceRoot/ext
        cp -r ${inputs.gui_toolkit} $sourceRoot/ext/gui_toolkit
        chmod -R u+w $sourceRoot/ext/gui_toolkit
      '';
      # the crates of the toolkit's native library, vendored: cargo makes no request
      cargoDeps = pkgs.rustPlatform.importCargoLock {lockFile = "${inputs.gui_toolkit}/native/gt/Cargo.lock";};
      nativeBuildInputs = [odin pkgs.cargo pkgs.rustc pkgs.clang pkgs.lld pkgs.autoPatchelfHook pkgs.copyDesktopItems pkgs.removeReferencesTo];
      buildInputs = [pkgs.fontconfig pkgs.freetype pkgs.stdenv.cc.cc.lib];
      # what it opens with dlopen goes in its RUNPATH; the Vulkan driver is the system's (/run/opengl-driver)
      runtimeDependencies = runtime;
      # Odin links a foreign library as -l:<absolute path> with -L/, which the purity check of the linker wrapper drops
      NIX_ENFORCE_PURITY = 0;
      configurePhase = ''
        runHook preConfigure
        export HOME="$TMPDIR"
        mkdir -p "$HOME/.cargo"
        cat > "$HOME/.cargo/config.toml" <<EOF
        [source.crates-io]
        replace-with = "vendored-sources"
        [source.vendored-sources]
        directory = "$cargoDeps"
        EOF
        export CARGO_NET_OFFLINE=true
        runHook postConfigure
      '';
      buildPhase = ''
        runHook preBuild
        mkdir -p build
        odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -- build release
        runHook postBuild
      '';
      desktopItems = [
        (pkgs.makeDesktopItem {
          name = "socle";
          desktopName = "Socle";
          genericName = "System Settings";
          comment = "Your whole system in one window.";
          exec = "socle";
          icon = "socle";
          categories = ["Settings" "System"];
          keywords = ["nixos" "settings" "apps" "system" "update"];
          startupWMClass = "socle";
        })
      ];
      installPhase = ''
        runHook preInstall
        # (the file itself, no wrapper: pkexec's rule names this path; git, nix and pkexec are the system's)
        install -Dm755 build/socle $out/bin/socle
        for size in 16 32 64 128 256; do
          install -Dm644 assets/logo_$size.png "$out/share/icons/hicolor/''${size}x''${size}/apps/socle.png"
        done
        install -Dm644 -t $out/share/doc/socle LICENSE README.md CHANGELOG.md
        # (the compiler's and the crates' source paths, in the debug information and Rust's panic messages: kept, they
        # would bring Odin, clang and LLVM into every system, 1.5 GB)
        remove-references-to -t ${odin} -t $cargoDeps $out/bin/socle
        runHook postInstall
      '';
      disallowedReferences = [odin];
      meta = {
        description = "Your whole system in one window: start from a ready-made system, change any setting, go back in one step.";
        homepage = "https://socle.froment.software/";
        license = lib.licenses.mit;
        platforms = [system];
        mainProgram = "socle";
      };
    };

    preCommitCheck = git-hooks.lib.${system}.run {
      package = pkgs.prek;
      src = ./.;
      hooks = {
        alejandra.enable = true;
        deadnix.enable = true;
        statix.enable = true;
      };
    };
  in {
    lib = {inherit (socleLib) configuration;};
    nixosModules = {
      socle = import ./nix/modules {inherit self inputs;};
      default = self.nixosModules.socle;
    };
    homeModules = {
      socle = import ./nix/home {inherit self;};
      default = self.homeModules.socle;
    };
    socleTemplates = import ./nix/templates;

    packages.${system} = {
      inherit odin socle;
      default = socle;
      # socle's live images (nix/images.nix)
      iso-desktop = self.nixosConfigurations.image-desktop.config.system.build.isoImage;
      iso-minimal = self.nixosConfigurations.image-minimal.config.system.build.isoImage;
    };
    apps.${system} = {
      default = {
        type = "app";
        program = "${socle}/bin/socle";
      };
      # the test bed: a NixOS that socle manages, in a virtual machine (nix/vm.nix); its disk is ./socle-vm.qcow2
      vm = {
        type = "app";
        program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-socle-vm-vm";
      };
    };
    # opt-in tests (not in checks): a virtual machine each
    legacyPackages.${system}.tests = import ./nix/tests.nix {
      inherit self inputs lib pkgs;
      inherit socleLib images;
    };
    nixosConfigurations = {
      vm = import ./nix/vm.nix {
        inherit self inputs lib;
        inherit socleLib;
      };
      inherit (images) image-desktop image-minimal;
    };
    checks.${system} =
      {
        pre-commit = preCommitCheck;
      }
      // import ./nix/checks.nix {
        inherit pkgs lib inputs;
        inherit socleLib;
      };
    formatter.${system} = pkgs.alejandra;

    devShells.${system}.default = pkgs.mkShell {
      # (cargo and rustc: the toolkit's text library)
      packages = [odin] ++ (with pkgs; [cargo rustc]) ++ preCommitCheck.enabledPackages;
      buildInputs = [pkgs.fontconfig];
      shellHook =
        preCommitCheck.shellHook
        + ''
          export LD_LIBRARY_PATH=${lib.makeLibraryPath runtime}
        '';
    };
  };
}
