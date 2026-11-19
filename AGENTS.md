# socle

A control panel for a whole NixOS system, in Odin, on the `ext/gui_toolkit` submodule (collection `gt`). socle owns
one configuration: it creates it from a template, changes it from forms, builds it and switches to it, and goes back
to an earlier generation. The person never has to write Nix; the configuration stays a plain flake that builds without
socle.

Read first: [README.md](README.md), [src/md/README.md](src/md/README.md) (the intent), [ROADMAP.md](ROADMAP.md),
[docs/development.md](docs/development.md).

## Build and test

Every step is a command of `tools/socletool` (`help` lists them):

    odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -keep-executable -- <command>

- `changelog new|check|preview`. `build`, `test` and `check` come with the first code of the program.
- `mockups [names]` draws `docs/mockups/*.html` to PNG with a headless Chromium (`CHROMIUM=<program>` for another).
- Linux: `nix develop` first (`flake.nix`: the pinned Odin, Rust, the hooks).

## Rules

- The interface's thread never waits. No `nix`, `git`, disk, process or D-Bus call runs there, not even a `stat`. Each
  such call is a job on a worker; its result comes back with `ui.post`.
- socle writes only its own files: the layers (`socle/**/*.json`), the hardware reports and the generated `flake.nix`.
  It never reads, parses or rewrites Nix that a person wrote. The person's Nix lives in `custom/`, imported as it is.
- The configuration that socle manages builds without socle: `nixos-rebuild switch --flake <folder>#<host>` works on
  it. A test checks it.
- The window never runs as root. Only the helper (`socle-helper`, a system service) switches, and it takes a fixed set
  of verbs with a store path that it checks, never a command line.
- The form of a feature comes from its NixOS option declarations (type, default, description). Do not write a second
  schema for it.
- Tests never touch the person's system: they make a configuration in a temporary folder, evaluate it and build it,
  and never switch. A switch is tested only in a virtual machine, opt-in.
- What more than one program needs goes in gui_toolkit, generic, with its docs, test and changelog fragment; socle then
  points to the toolkit's new tag.
- Automation is a command of `tools/socletool`, never a shell, batch, PowerShell, Python or Node script.
- Comments and commit messages are in English. Comments say why.
- Commits: author and committer `sachahjkl <sacha@sacha.house>`, no attribution trailer, no session link.

## Changelog

- `CHANGELOG.md` follows Keep a Changelog and semantic versioning. It is never edited by hand.
- A change a person sees is one fragment in `changelog.d/` (its README says the format), written by
  `socletool changelog new <type> <text>`, in the same commit as the change.
- `socletool ship` assembles the fragments into the version's section; `socletool check` checks the fragments and
  the file.

## Roadmap

- `ROADMAP.md`, beside `CHANGELOG.md`, holds socle's planned work: `# Roadmap`, then `## Now`, `## Next` and
  `## Later`, each a list. An optional `## Maybe` comes last. Each entry starts with a bold summary, then one or two
  sentences on what it gives the user. No dates, no front matter.
- When a work is done, remove its entry in the same commit as its changelog fragment.
- Work that touches several programs goes in the roadmap of gui_toolkit.
- `socletool check` checks its format with the changelog's.

## Intent

This project follows <https://srcmd.org>, with the Markdown in `src/md`. Read `src/md/README.md` first.

- Change the intent first, then derive the code and the tests. A change of design changes its intent file in the same
  commit.
- Keep there what the code does not show: the purpose, the decisions, the refused alternatives, the subtle points.
- `src/md/README.md` lists every other file of the folder in its `## File Index`.
- The user's documentation and the developer's how-to stay in `docs/`; `src/md` links to them. The mockups are in
  `docs/mockups/`.

## Key prompts

Apply these to every task, before you write code:

- "Exercise abstract thinking when considering this task."
- "Reduce this problem to its irreducible constraints and rebuild it from zero."
- "What would a principal architect immediately rewrite before even starting this?"
- "Design the single test that breaks this design on day one."
- "What higher-level abstraction would make this entire problem disappear?"
- "Find all of the implicit state machines in my app."
