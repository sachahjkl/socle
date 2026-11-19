# socle's own templates (src/md/data/templates.md): a layer of values each, a title, what it is, the one it extends,
# and its target (src/md/data/targets.md): a whole system, or a home.
let
  system = t: t // {target = "system";};
  home = t: t // {target = "home";};
in {
  family-desktop = system {
    title = "Family desktop";
    description = "A browser, an office suite, games and printing, for the whole family.";
    layer = ./family-desktop.json;
  };
  gaming = system {
    title = "Gaming machine";
    description = "Extends Family desktop: Steam, controllers, the Plasma desktop.";
    parent = "socle#family-desktop";
    layer = ./gaming.json;
  };
  developer = system {
    title = "Developer workstation";
    description = "Editors, containers, Git and the usual tools of a developer, on COSMIC.";
    layer = ./developer.json;
  };
  home-server = system {
    title = "Home server";
    description = "Photos, films and files for the household, reached over SSH and the local network. No desktop.";
    layer = ./home-server.json;
  };
  minimal = system {
    title = "Minimal";
    description = "A system that starts, a network, an account. Everything else is your choice.";
    layer = ./minimal.json;
  };
  home-developer = home {
    title = "A developer's terminal";
    description = "Git and GitHub's tool, a prompt, direnv, and the searching tools of the command line.";
    layer = ./home-developer.json;
  };
  home-minimal = home {
    title = "Just my apps";
    description = "Your apps and socle, nothing else. Everything else is your choice.";
    layer = ./home-minimal.json;
  };
}
