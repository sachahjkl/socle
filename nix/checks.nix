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
  # a home (tests/home): its template's tools, the person's own app, one the person removed, the layers' hash
  homeOf = system:
    (socleLib.configuration ({
        inherit inputs;
        root = ../tests/home;
      }
      // lib.optionalAttrs (system != null) {inherit system;}))
    .homeConfigurations
    .ada;
  home = (homeOf null).activationPackage;
  # every template, of its target: it evaluates to a derivation (a system's without the socle program: the eject)
  templates = lib.mapAttrsToList (name: t: let
    layer = {
      socle = 1;
      template = "socle#${name}";
      values = {};
    };
  in
    builtins.unsafeDiscardStringContext (
      if t.target == "home"
      then (homeOf layer).activationPackage.drvPath
      else (sample layer).config.system.build.toplevel.drvPath
    ))
  inputs.self.socleTemplates;
in {
  layers = pkgs.writeText "socle-layers" (lib.concatStringsSep "\n" layers);
  templates = pkgs.writeText "socle-templates" (lib.concatStringsSep "\n" templates);
  homes = pkgs.runCommand "socle-homes" {} ''
    p=${home}/home-path/bin
    test -e $p/hello || { echo "the person's app is missing"; exit 1; }
    test -e $p/rg || { echo "the template's ripgrep is missing"; exit 1; }
    ! test -e $p/just || { echo "the template's just, removed by the person, stays"; exit 1; }
    ! test -e $p/gh || { echo "GitHub's tool, turned off by the person, stays"; exit 1; }
    test -e $p/socle || { echo "socle is not in the home"; exit 1; }
    test "$(wc -c < ${home}/socle-revision)" = 64 || { echo "the revision is not the layers' hash"; exit 1; }
    test -x ${home}/activate
    touch $out
  '';
}
