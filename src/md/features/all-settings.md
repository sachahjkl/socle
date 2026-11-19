# All settings

The features cover what most people need. "All settings" reaches every option of the system: NixOS's, socle's and the
templates'.

## The index of options

- The catalogue worker builds `config.system.build.manual.optionsJSON` of the host: names, types, defaults,
  descriptions, declarations. It has the options of every module of this configuration, the templates' too.
- It is built once per lock and per set of modules, and kept. A search runs on the worker, by name and description.
- Internal and read-only options are hidden.

## The value and its source

When the person selects an option, the evaluator reads two things: `config.<path>` (the value) and
`options.<path>.definitionsWithLocations`. Each layer is a module with its `_file`, so the source reads "set by the
template Family desktop", "by you", "by this machine", "in custom/gaming.nix", or "by NixOS" (the default or a module).

## What data can hold

- Data holds `bool`, `int`, `float`, `str`, `enum`, `null`, paths given as absolute strings, packages given by name,
  and lists, sets and submodules of these.
- Data cannot hold a function, an overlay, a derivation built in place, or a value of type `raw`. For those, the page
  shows the value read only and a button "Set it in code": it creates `custom/<option>.nix` with the option's path and
  its current value as a comment, and opens it in the person's editor. socle then adds the file to git.

## A list

A list value of the person adds to the modules' items ([../data/configuration.md](../data/configuration.md)). The page
shows the modules' items greyed and the person's items as tags. "Replace the whole list" is a separate action with a
warning.

## Expert words

A preference shows the NixOS names next to the person's words everywhere in the window (the option path under each
title). It is off by default.
