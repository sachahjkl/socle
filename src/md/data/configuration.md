# The configuration

## The folder

socle manages one folder, `/etc/socle`, a git repository. Its group is `wheel` and its mode is `2775`: an
administrator edits the draft without root, and only the switch needs root.

```
/etc/socle/
  flake.nix                  generated, a fixed form: the inputs and one call to socle's library
  flake.lock
  socle/system.json          the person's layer for every machine of this folder
  socle/hosts/<host>.json    the layer of one machine: its release, its disk, its passwords
  hosts/<host>/facter.json   the hardware report of the machine (nixos-facter), data too
  custom/*.nix               the person's Nix, imported as it is
```

The generated `flake.nix` holds no logic:

```nix
{
  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2605";
  inputs.socle.url = "github:sachahjkl/socle";
  inputs.template-family-desktop.url = "github:someone/family-desktop";
  outputs = inputs: inputs.socle.lib.configuration {inherit inputs; root = ./.;};
}
```

`socle.lib.configuration` reads the layers and returns `nixosConfigurations.<host>` for each file of `socle/hosts/`.

## The layers

From the lowest to the highest:

| Layer | Source | Priority of a value |
|---|---|---|
| The defaults | the option declarations of NixOS and of socle's features | 1500 (`default`) |
| The templates | the root template first, the leaf template last | 99 (root) to 95 (leaf) |
| The system | `socle/system.json` | 90 |
| The machine | `socle/hosts/<host>.json` | 89 |
| The code | `custom/*.nix` | as written |

- A value of a layer beats a normal definition (100) of a NixOS module. A template that picks a desktop wins over the
  `mkDefault` and the normal values of the modules. The person beats the templates.
- `custom/` beats socle's layers only with `mkForce` (50). The code is the expert's tool; it must say that it wins.
- Each layer is a NixOS module with `_file` set to its path. NixOS then reports where each value comes from
  (`definitionsWithLocations`), and the window shows it without bookkeeping of its own.

## The JSON form

A layer is the `config` of a module, nested as Nix nests it:

```json
{
  "socle": 1,
  "values": {
    "socle": {"desktop": {"environment": "plasma"}, "packages": {"firefox": true, "vlc": false}},
    "services": {"printing": {"enable": true}},
    "time": {"timeZone": "Europe/Paris"}
  }
}
```

`socle` is the version of the form. A package is its attribute path as a string; the library resolves it.

## The priorities go to the options, not to the tree

`mkOverride` on an attribute set gives its priority to the definition of each option below it. On `users.users`, the
person's definition at 90 would then discard every lower definition of `users.users`: the modules' system users would
vanish. So the library walks the values with the option declarations and wraps each value at its own option. It
descends into submodules (`attrsOf (submodule …)`) through `type.getSubOptions`.

A walk of the JSON alone was refused: it cannot tell an option of type `attrs` (wrap the whole value) from a set of
options (wrap each one).

## Lists add, sets replace

- A value at 90 discards the definitions at 100. For a list option that many modules fill
  (`environment.systemPackages`), that discards them all. So a list value of a layer is added at priority 100: it
  joins the modules' items and removes none.
- To replace a whole list is an explicit choice of the person (`mkForce`), and the window warns.
- socle's own collections are sets keyed by name (`attrsOf bool`): any layer can remove what a lower layer added
  (`"vlc": false`).

## The eject

The folder builds with `nixos-rebuild switch --flake /etc/socle#<host>`, with no socle program. The library stays an
input. A person who leaves socle keeps a working flake and can move the values to Nix at their own pace.

## Refused

- **Write Nix code.** A round trip through a Nix parser loses or breaks the person's comments, layout and edits, and
  socle would have to understand any expression. Data has none of these problems.
- **Merge the layers in socle.** It reimplements the module system and loses the source of each value.
- **The classic `/etc/nixos/configuration.nix` without a flake.** No lock: a template's version and Nixpkgs's version
  are not pinned, and a build cannot be repeated.
