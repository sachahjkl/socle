# socle's library: a folder of layers (data) becomes a set of NixOS systems. src/md/data/configuration.md says why the
# layers are data and how their priorities work.
{
  lib,
  socle, # socle's flake: its NixOS module and its templates
}: let
  inherit (builtins) fromJSON readFile pathExists readDir attrNames hashString elem isAttrs;

  # The priorities of the layers' values (configuration.md, "The layers"): above a normal definition of a module (100),
  # below mkForce (50). A template chain goes from TEMPLATE_ROOT down to TEMPLATE_LEAF.
  priority = {
    host = 89;
    system = 90;
    templateLeaf = 95;
    templateRoot = 99;
  };

  readJSON = path:
    if pathExists path
    then fromJSON (readFile path)
    else {};
  readText = path:
    if pathExists path
    then readFile path
    else "";
  valuesOf = layer: layer.values or {};

  # `value` given to the options under `opts` at `prio`: each value wrapped at its own option, never a whole tree, so a
  # person's users.users.ada does not discard the users that the modules define (configuration.md, "The priorities go
  # to the options").
  wrap = prio: opts: value:
    if lib.isOption opts
    then wrapOption prio opts value
    else if isAttrs value
    then
      lib.mapAttrs (name: v:
        if isAttrs opts && opts ? ${name}
        then wrap prio opts.${name} v
        else throw "socle: the layer sets ${name}, which is no option")
      value
    else throw "socle: the layer gives a value where options are expected";

  wrapOption = prio: opt: value: let
    t = opt.type;
    item = t.nestedTypes.elemType or null;
  in
    # (a list adds to the modules' items at their priority: a list at 90 would discard them all)
    if elem t.name ["listOf" "nonEmptyListOf"]
    then value
    else if elem t.name ["attrsOf" "lazyAttrsOf"] && isAttrs value
    then
      lib.mapAttrs (_: v:
        if item != null && item.name == "submodule"
        then wrap prio (item.getSubOptions []) v
        else lib.mkOverride prio v)
      value
    else if t.name == "submodule" && isAttrs value
    then wrap prio (t.getSubOptions []) value
    else lib.mkOverride prio value;

  # A layer as a NixOS module: its file says where each value comes from (definitionsWithLocations).
  layerModule = file: prio: values: {options, ...}: {
    _file = toString file;
    config = wrap prio options values;
  };

  # A template by its reference "<input>#<name>" ("socle#family-desktop": one of socle's own).
  templateOf = inputs: ref: let
    parts = lib.splitString "#" ref;
    input = builtins.head parts;
    name = lib.last parts;
    source =
      if input == "socle"
      then socle
      else inputs.${input} or (throw "socle: no input ${input} for the template ${ref}");
  in
    (source.socleTemplates.${name} or (throw "socle: ${input} has no template ${name}")) // {inherit ref;};

  # A template and its parents, the root first. At most five deep; a loop is refused.
  chainOf = inputs: ref: let
    go = seen: r:
      if r == null
      then []
      else if elem r seen
      then throw "socle: the templates loop at ${r}"
      else if builtins.length seen >= 5
      then throw "socle: the template chain is more than five deep at ${r}"
      else let t = templateOf inputs r; in go (seen ++ [r]) (t.parent or null) ++ [t];
  in
    go [] ref;

  # The folder `root` as NixOS systems, one per socle/hosts/<host>.json. `system`: the system layer given instead of
  # socle/system.json (a test's).
  configuration = {
    inputs,
    root,
    system ? null,
  }: let
    systemFile = root + "/socle/system.json";
    systemLayer =
      if system != null
      then system
      else readJSON systemFile;
    templates = chainOf inputs (systemLayer.template or null);
    count = builtins.length templates;
    hostsDir = root + "/socle/hosts";
    hosts =
      if pathExists hostsDir
      then map (lib.removeSuffix ".json") (builtins.filter (lib.hasSuffix ".json") (attrNames (readDir hostsDir)))
      else [];
    customDir = root + "/custom";
    custom =
      if pathExists customDir
      then map (n: customDir + "/${n}") (builtins.filter (lib.hasSuffix ".nix") (attrNames (readDir customDir)))
      else [];

    # the modules of a machine: socle's, its identity, its hardware, the templates' code and layers, the person's
    # layers, the person's code
    modulesFor = name: let
      hostFile = hostsDir + "/${name}.json";
      hostLayer = readJSON hostFile;
      hardware = root + "/hosts/${name}";
      # (the hash of the layers that made the system: the history joins versions and commits by it, apply.md)
      # (a system layer given is hashed as its JSON: the text a folder written from it holds)
      revision = hashString "sha256" ((
          if system != null
          then builtins.toJSON system
          else readText systemFile
        )
        + readText hostFile);
    in
      [
        socle.nixosModules.socle
        {
          networking.hostName = lib.mkDefault name;
          nixpkgs.hostPlatform = lib.mkDefault (hostLayer.platform or "x86_64-linux");
          socle = {
            inherit revision;
            host = name;
            template = systemLayer.template or "";
          };
        }
      ]
      ++ lib.optional (pathExists (hardware + "/facter.json")) {hardware.facter.reportPath = hardware + "/facter.json";}
      ++ lib.optional (pathExists (hardware + "/hardware.nix")) (hardware + "/hardware.nix")
      ++ lib.concatMap (t: t.modules or []) templates
      ++ lib.imap0 (i: t: layerModule t.layer (priority.templateLeaf + (count - 1 - i)) (valuesOf (readJSON t.layer))) templates
      ++ [
        (layerModule systemFile priority.system (valuesOf systemLayer))
        (layerModule hostFile priority.host (valuesOf hostLayer))
      ]
      ++ custom;

    nixosFor = name: inputs.nixpkgs.lib.nixosSystem {modules = modulesFor name;};

    systems = lib.genAttrs hosts nixosFor;

    # What the window reads of a host in one evaluation (features.md): socle's settings as they result, the
    # templates' values alone, the defaults, the pages, the popular apps with their versions, the gallery.
    infoFor = name: let
      c = systems.${name};
      inherit (c) config pkgs;
      templateValues = lib.foldl lib.recursiveUpdate {} (map (t: valuesOf (readJSON t.layer)) templates);
      defaults = lib.mapAttrsRecursiveCond (x: !lib.isOption x) (_: o: o.default or null) (removeAttrs c.options.socle ["ui" "revision" "host" "template" "package"]);
      scalar = v: builtins.isBool v || builtins.isInt v || builtins.isString v || builtins.isFloat v;
      # an option of a page, as the window shows it: its declaration's type, values and words, and its value now
      fact = path: let
        parts = lib.splitString "." path;
        opt = lib.attrByPath parts null c.options;
        payload = opt.type.functor.payload or null;
        value = lib.attrByPath parts null config;
      in
        if opt == null || !(lib.isOption opt)
        then null
        else {
          type = opt.type.name;
          description = let
            d = opt.description or "";
          in
            if builtins.isString d
            then d
            else d.text or "";
          enums =
            if opt.type.name == "enum"
            then
              (
                if builtins.isAttrs payload
                then payload.values or []
                else if builtins.isList payload
                then payload
                else []
              )
            else [];
          value =
            if scalar value
            then value
            else null;
          default =
            if opt ? default && scalar opt.default
            then opt.default
            else null;
        };
      paths = lib.unique (lib.concatMap (p: p.options) (builtins.attrValues config.socle.ui.pages));
    in {
      effective = removeAttrs config.socle ["ui" "package"];
      template = templateValues;
      inherit defaults;
      templates = map (t: {inherit (t) ref title;}) templates;
      pages = config.socle.ui.pages;
      facts = lib.filterAttrs (_: f: f != null) (lib.genAttrs paths fact);
      # (the running system's facts the overview shows)
      nixos = config.system.nixos.release;
      # (the locked Nixpkgs, which the Apps page searches: nix search on this path)
      nixpkgs = inputs.nixpkgs.outPath;
      inputs = lib.mapAttrs (_: i: {lastModified = i.lastModified or 0;}) (removeAttrs inputs ["self"]);
      popular = map (a: let
        p = lib.attrByPath (lib.splitString "." a.attr) null pkgs;
      in
        a
        // {
          version = p.version or "";
          unfree = !(p.meta.license.free or true);
        })
      (import ./popular.nix);
      gallery =
        lib.mapAttrsToList (n: t: {
          ref = "socle#${n}";
          inherit (t) title description;
          parent = t.parent or null;
        })
        socle.socleTemplates;
    };
  in {
    nixosConfigurations = systems;
    socleInfo = lib.genAttrs hosts infoFor;
    # (a NixOS test's machine is made of the same modules: nix/tests.nix)
    socleModules = lib.genAttrs hosts modulesFor;
    # every option of a machine, as All settings searches them: built apart from the system's manual, which the base
    # leaves out
    socleOptions = lib.genAttrs hosts (name:
      (systems.${name}.pkgs.nixosOptionsDoc {
        inherit (systems.${name}) options;
        warningsAreErrors = false;
      })
      .optionsJSON);
  };
in {
  inherit configuration wrap priority chainOf;
}
