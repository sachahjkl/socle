# socle's own templates (src/md/data/templates.md): a layer of values each, a title, what it is, the one it extends.
{
  family-desktop = {
    title = "Family desktop";
    description = "A browser, an office suite, games and printing, for the whole family.";
    layer = ./family-desktop.json;
  };
  gaming = {
    title = "Gaming machine";
    description = "Extends Family desktop: Steam, controllers, the Plasma desktop.";
    parent = "socle#family-desktop";
    layer = ./gaming.json;
  };
  developer = {
    title = "Developer workstation";
    description = "Editors, containers, Git and the usual tools of a developer, on COSMIC.";
    layer = ./developer.json;
  };
  home-server = {
    title = "Home server";
    description = "Photos, films and files for the household, reached over SSH and the local network. No desktop.";
    layer = ./home-server.json;
  };
  minimal = {
    title = "Minimal";
    description = "A system that starts, a network, an account. Everything else is your choice.";
    layer = ./minimal.json;
  };
}
