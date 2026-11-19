# What the library tells a configuration about itself, for a system and for a home alike (src/md/data/targets.md).
{lib, ...}: {
  options.socle = {
    revision = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The hash of the layers that made this version: the history joins versions and commits by it.";
    };
    host = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The machine's or the home's name in the folder (socle/hosts/<name>.json, socle/homes/<name>.json).";
    };
    template = lib.mkOption {
      type = lib.types.str;
      default = "";
      internal = true;
      description = "The template the configuration starts from, as <input>#<name>.";
    };
  };
}
