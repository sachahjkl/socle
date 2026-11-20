# Templates

A template is a ready-made system: a set of settings with a title and a description. Your own settings always stay over
the template's: change the template, and what you set is kept.

## Socle's templates

| Template | What it gives |
|---|---|
| Family desktop | A browser, an office suite, games and printing, on GNOME |
| Gaming machine | Family desktop, with Steam, controllers and the Plasma desktop |
| Developer workstation | Editors, containers, Git and the usual tools, on COSMIC |
| Home server | Photos, films and files for the household, SSH, no desktop |
| Minimal | A system that starts, a network, an account |
| A developer's terminal (home) | Git, a prompt, direnv and the searching tools |
| Just my apps (home) | Your apps and Socle |

To change template, open **Templates** and click **Start from this one**. The review shows the change. A template can
extend another one: Gaming machine extends Family desktop.

## Save your own

**Templates → Save as a template** saves the applied system as a template: give it a title and a line that says what
it is. Socle writes a git repository in `~/socle-templates/<name>`:

| File | What it holds |
|---|---|
| `flake.nix` | The flake that gives the template, as `socleTemplates.<name>` |
| `template.json` | Its title, its description, its target (a system or a home), the template it extends |
| `layer.json` | Its settings |
| `README.md` | How to start from it |

The template holds your settings only: not the people, not their accounts or passwords, not this machine's disk or
language. It extends the same template of Socle's as your system. If your system extends a template from elsewhere,
that template's settings are copied into the new one, so that it works where that template is not known.

## Share it

Push the folder to any git host:

```sh
cd ~/socle-templates/<name>
git remote add origin git@github.com:<you>/<repository>.git
git push -u origin HEAD
```

Anyone can then start from it with the link `github:<you>/<repository>#<name>`.

## Start from a link

**Templates → From a link** takes a template's address: `github:owner/repository#name`. GitLab
(`gitlab:owner/repository#name`), any git server (`git+https://…#name`) and a local folder (`path:/home/ada/t#name`)
work too. Socle adds the template's flake to the folder, and your system starts from it. Nothing changes until you
apply, and **Discard** removes the link.

The gallery then shows every template of that flake.

## Trust

A template runs as an administrator when the system is built: its settings configure services, and a template can
carry its own Nix code. The gallery marks such a template **Runs its own Nix**. Start only from the templates of people
you trust, and read the review before you apply.
