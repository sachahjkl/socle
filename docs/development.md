# Development

## Setup

```sh
git clone --recurse-submodules https://github.com/sachahjkl/socle
cd socle
nix develop        # the pinned Odin with wgpu-native, Rust (the toolkit's text library), the git hooks
```

Without Nix: Odin `dev-2026-11a` (`odin.version`), clang and lld, cargo, wgpu-native's static library in Odin's
`vendor/wgpu/lib` (`odin run ext/gui_toolkit/tools/tk -- fetch_wgpu`), fontconfig. socle drives `nix` and `git`: both
must be on the path at run time.

## socletool

Every step is a command of `tools/socletool`. `./build.sh` is its shortcut for `build`.

```sh
odin run tools/socletool -collection:gt=ext/gui_toolkit/src -out:build/socletool -keep-executable -- help
```

| Command | What it does |
|---|---|
| `changelog new <type> <text>`, `check`, `preview` | a fragment of `changelog.d/`, their check, what the next version brings |
| `ship <patch\|minor\|major\|x.y.z>`, `notes <version>` | a version: the changelog's section, `src/version.odin`, the commit, the tag, the push; a version's notes |
| `logo` | `assets/logo*.png`, `assets/socle.ico` and `.project/image.png`, drawn by the toolkit's paint package |
| `mockups [names]` | `docs/mockups/*.html` drawn to PNG at 1280 × 800 by a headless Chromium |
| `build [release]`, `test`, `check` | the program `build/socle` (the toolkit's native library first), its tests, every check (gui_toolkit's `toolbox.build_commands`) |
| `film [out.mp4]` | the presentation film: `tools/socle_film` drives socle's window headless on the graphics card (gt:film), ffmpeg encodes it (NVENC when there is one): `site/socle.mp4` |
| `site build <site> <out>`, `check`, `card` | the site's pages (gt:site), published by `.github/workflows/pages.yml` |

`build`, `test` and `check` come from gui_toolkit (`toolbox.build_commands`) with the first code of the program.
`GT=<folder>` builds against another checkout of gui_toolkit.

## A change

- Comments and commit messages are in English. Comments say why.
- A change of design changes its intent file in `src/md` in the same commit.
- A change a person sees has its fragment in `changelog.d/`.
