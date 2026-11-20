# Everyday use

## The window

- **The bar at the top** names the machine and the version that runs. The search box opens **All settings**.
- **The pages on the left** each show a part of the system. Socle's own pages (Apps, People, Desktop) come first, then
  a page for each part that the system declares (Hardware, Sound, Network, Printing, Gaming, Sharing, Start and
  power), then **Updates**, **History**, **Templates** and **All settings**.
- **The bar at the bottom** shows only while changes wait: how many, **Discard**, and **Review and apply**.

## A change

Every control saves its change at once. There is no Save button. A dot beside a setting marks a change that is not
applied yet, and **Back to the template** removes your value so that the template's shows again.

After each change, Socle checks that the system still evaluates. When it does not, the dot in the bottom bar turns
red, and the review shows Nix's words.

**Discard** removes every change since the last applied version, with any template link or update of the sources.

## Apps

- The list shows the popular apps first. The search covers every package of Nixpkgs (more than 100,000).
- **For everyone** installs an app for every account. A person's name installs it for that person only.
- An app whose licence is not free says **Not free**. You accept its licence when you add it.

## People

Each account, and whether it administers the machine. **Add a person** creates an account with no password: its owner
sets one at the first login, or an administrator sets it with `passwd`.

## Review and apply

1. **Review and apply** lists every change in words.
2. Choose when:
   - **Now, on trial**: the new version runs at once. A dialog counts down from 60 seconds. **Keep** keeps it; **Go
     back now**, or no answer, runs the version before again.
   - **At the next start**: the new version waits for the next start of the machine. Choose it when the desktop
     changes, because the session closes. Socle suggests it then.
3. **Prepare and apply** downloads and builds. The bottom bar shows the progress. An administrator's password is
   asked once, then not again for five minutes.

When a version is kept, Socle records it in its folder's git history, with the review's words as its message.

## History

Every version of the system, the newest first, with the changes that made it. **Go back to it** runs an earlier
version with the same try and keep: nothing is built. A version made by `nixos-rebuild` or another tool says so.

When there are more versions than **Start and power** keeps (ten unless you change it), **Free space** removes the
older ones and gives back their disk space. A weekly clean does the same by itself.

## Updates

**Look for updates** moves the software catalogue (Nixpkgs) and Socle forward. The update is a change like the others:
review it, apply it, keep it or go back.

## All settings

Every option of NixOS (or of Home Manager, for a home), with search. Each option shows its value and **who sets it**:

1. **This machine**: its own layer, written by the install or the takeover (its disk, language, accounts' passwords).
2. **You**: your changes.
3. **The template**.
4. **NixOS and its modules**: the default.

The first that sets a value wins.
