# socle's Home Manager module: part of every home that socle manages (src/md/data/targets.md). The same model as a
# system's: the layers set `socle.*` and Home Manager's options, the window shows the pages that `socle.ui` lists.
{self}: {
  imports = [
    ../shared/identity.nix
    ../shared/ui.nix
    ./apps.nix
    ./base.nix
    ./pages.nix
    ./program.nix
  ];

  config._module.args.socleSelf = self;
}
