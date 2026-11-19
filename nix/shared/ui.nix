# The pages of the window: a declaration cannot carry a page, an icon or an order, so each feature sets them here
# (src/md/features/features.md, "What a declaration cannot say").
{lib, ...}: {
  options.socle.ui.pages = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        title = lib.mkOption {type = lib.types.str;};
        icon = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "A Lucide icon's name.";
        };
        group = lib.mkOption {
          type = lib.types.enum ["System" "Manage"];
          default = "System";
        };
        order = lib.mkOption {
          type = lib.types.int;
          default = 50;
        };
        options = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "The options the page shows, by their path.";
        };
      };
    });
    default = {};
    description = "The pages of socle's window that the features add.";
  };
}
