# The tests that can break the design (src/md/README.md, "The first tests"): they evaluate, never switch.
{
  pkgs,
  lib,
  socleLib,
  inputs,
}: let
  # (a system layer given: the bare machine, whose own layer sets only its disks)
  sample = system:
    (socleLib.configuration ({
        inherit inputs;
        root =
          if system == null
          then ../tests/sample
          else ../tests/bare;
      }
      // lib.optionalAttrs (system != null) {inherit system;}))
  .nixosConfigurations
  .test;
  c = (sample null).config;
  names = map lib.getName c.environment.systemPackages;
  expect = what: ok:
    if ok
    then what
    else throw "socle's layers test: ${what}";
  # (every check evaluated when the derivation is: its name holds them all)
  layers = [
    (expect "the person removes the template's VLC" (!(builtins.elem "vlc" names)))
    (expect "the template's Firefox stays" (builtins.elem "firefox" names))
    (expect "the person adds mpv" (builtins.elem "mpv-with-scripts" names))
    (expect "the modules' packages stay (nano)" (builtins.elem "nano" names))
    (expect "the template's desktop is GNOME" (c.socle.desktop.environment == "gnome"))
    (expect "ada administers the machine" (builtins.elem "wheel" c.users.users.ada.extraGroups))
    (expect "the machine's layer adds to ada's groups" (builtins.elem "docker" c.users.users.ada.extraGroups))
    (expect "root stays" (c.users.users ? root))
    (expect "the modules' system users stay (nixbld1)" (c.users.users ? nixbld1))
    (expect "the template's printing is on" c.services.printing.enable)
    (expect "ada logs in by itself" (c.services.displayManager.autoLogin.user == "ada"))
    (expect "the revision is the layers' hash" (builtins.stringLength c.socle.revision == 64))
  ];
  # every template, as a system: it evaluates to a system's derivation without the socle program (the eject)
  templates = lib.mapAttrsToList (name: _: let
    t = sample {
      socle = 1;
      template = "socle#${name}";
      values = {};
    };
  in
    builtins.unsafeDiscardStringContext t.config.system.build.toplevel.drvPath)
  inputs.self.socleTemplates;
in {
  layers = pkgs.writeText "socle-layers" (lib.concatStringsSep "\n" layers);
  templates = pkgs.writeText "socle-templates" (lib.concatStringsSep "\n" templates);
}
