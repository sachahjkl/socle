# Templates

A template is a ready-made system: a layer of values, a title, a description and pictures. "Family desktop", "Gaming
machine", "Developer workstation", "Home server" and "Minimal" ship with socle's library.

## The form

A template is a flake output:

```nix
socleTemplates.family-desktop = {
  title = "Family desktop";
  description = "A desktop for the whole family: a browser, an office suite, games, parental limits.";
  pictures = [./pictures/desktop.png];
  parent = null;                 # or "<input>#<name>": the template that this one extends
  layer = ./layer.json;          # the same form as socle/system.json
  modules = [];                  # Nix of the template's author, if any
};
```

- A template made by socle ("Save as template") holds only `layer.json`. A person who writes Nix can add `modules`.
- A template is a flake input of the configuration. Its version is in `flake.lock`, so the same folder builds the same
  system in a year.

## Extend

`parent` makes a chain: "Gaming machine" can extend "Family desktop". The chain gives the template priorities, from 99
at the root to 95 at the leaf (see [configuration.md](configuration.md)). A chain is at most five templates deep. A
chain that loops is refused when the configuration is evaluated.

## Follow

- A new version of a template is an update of its input. The Updates page shows it with the same review as any change:
  which values move, what the person already replaced.
- A value that the person set stays theirs. The window marks it "changed by you", with "Back to the template" to
  remove it from the person's layer.
- To change template is to replace the input and keep the person's layers. The review shows which of the person's
  values become useless (the new template already has them) and offers to remove them.

## Save as template

- The export takes the applied `socle/system.json` only (the folder's last commit, not the draft). The machine's layer
  (`socle/hosts/<host>.json`) stays: it holds the host name, the disk, the password hashes. This is why there are two
  layers for the person.
- It leaves out `socle.people` and `users`: a template gives a system, not its accounts.
- A parent of socle's stays a parent (`socle#family-desktop`): every configuration has the input `socle`. Another
  parent is flattened into the layer (the chain's values, under the person's): the configuration that starts from the
  template may not have that parent's input.
- The export writes a new git repository, `~/socle-templates/<name>` (template.odin, `template_export`): `flake.nix`,
  `template.json` (title, description, target, parent: data, so no text needs escaping in Nix), `layer.json`, a
  README. The flake reads `template.json` and adds the layer. It can be pushed to any git host; `github:owner/repo#name`
  is then enough to start from it. Pictures wait.
- `custom/` is not exported.

## Start from a link

- The Templates page takes `<flake reference>#<name>`. socle adds the flake as an input of the folder's `flake.nix`
  and points the person's layer at `<input>#<name>`; the evaluation locks the input.
- socle writes `flake.nix` from data, `socle/inputs.json` (each input's name and address), and never reads the Nix of
  it. A folder made before `inputs.json` existed gets one from its `flake.lock`'s addresses.
- The gallery lists the templates of every input that has `socleTemplates`, with a mark when a template carries Nix
  code.

## Trust

A template is code that runs as root: its modules run at build time and its values configure services. The gallery
says who made a template and if it carries Nix modules. Before the first install, the review shows every value that
the template sets. socle's own templates are reviewed in this repository.

## The hub (maybe)

An online index of shared templates, searched from the gallery. The first form is an `index.json` in a git
repository: one entry per template, its flake reference, title, author and pictures; additions come by pull request.
A service with accounts and ratings waits until real templates exist.
