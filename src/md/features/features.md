# Features

NixOS has about 20 000 options, named for experts. A person thinks "a KDE desktop", "print to my printer", "play Steam
games". A **feature** is that level: a NixOS module of socle's library, with its options under `socle.<feature>`, that
sets the right NixOS options together.

```nix
options.socle.desktop.environment = lib.mkOption {
  type = lib.types.enum ["plasma" "gnome" "cosmic" "none"];
  default = "none";
  description = "The desktop that people see after they log in.";
};
config = lib.mkIf (cfg.environment == "plasma") {
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
};
```

## One schema: the option declarations

The page of a feature is made from its option declarations: the type gives the control, `description` (Markdown)
gives the help, `default` gives the "Default" mark. socle writes no second schema, so a page cannot drift from the
module.

| Type | Control |
|---|---|
| `bool` | a switch |
| `enum` of up to four values | a segmented control; more values: a list |
| `str`, `int`, `ints.between` | a field; the range is checked as the person types |
| `listOf str` | tags |
| `attrsOf bool` | a checklist, each item can be removed |
| `package` | the package picker ([apps.md](apps.md)) |
| `submodule`, `attrsOf (submodule …)` | a group, or a table of rows (the users) |
| any other type | read only, with "Set it in code" ([all-settings.md](all-settings.md)) |

## What a declaration cannot say

`mkOption` refuses attributes that it does not know: a declaration cannot carry a page, an icon or an order. A feature
sets them in an option of its own, `socle.ui`:

```nix
config.socle.ui.pages.desktop = {
  title = "Desktop"; icon = "monitor"; group = "System"; order = 10;
  options = ["socle.desktop.environment" "socle.desktop.autoLogin" "socle.desktop.wallpaper"];
};
```

The window evaluates `options.socle` and `config.socle.ui` once per change of the library or the templates, and keeps
the result. A template can add pages: its modules declare options and pages the same way.

## The checks

- The checks that need a type only (a range, an enum) run in the window, at once.
- Every other check is an evaluation of the draft by the evaluator. An assertion of NixOS ("Steam needs 32-bit
  graphics") comes back as a message on the page whose option the assertion names, or on the bar of changes if
  it names none.

## The first catalogue

Desktop, people, sound, network, Wi-Fi and Bluetooth, printing and scanning, graphics (including NVIDIA), gaming,
sharing (files, remote access), language and time, start and power, automatic updates, firewall, virtual machines and
containers, Flatpak.
