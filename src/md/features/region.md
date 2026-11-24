# Region

The Region page sets the machine's time zone, its language and its keyboard after the install. The installer asks the
same three things; this page is where a person changes them later.

## Where the values live

- The three values are NixOS's own options: `time.timeZone`, `i18n.defaultLocale` and `services.xserver.xkb.layout`.
  The page writes them as every page does: in the person's layer, `socle/system.json`.
- The installer writes them there too, not in the machine's layer. The machine's layer wins over the person's
  (configuration.md, "The layers") and the window never writes it: a value there could not be changed from any page,
  "All settings" included. The machine's layer keeps what only that machine has: its release, its disk, its passwords.
- One keyboard for the desktop and the console: `console.useXkbConfig` is set by socle's base (`mkDefault`), not
  written in a layer. The passphrase typed at the start is then typed on the keyboard the person chose.
- A folder for several machines (ROADMAP, "Later") gives them one region. A machine in another time zone then needs
  its own value; that waits for the window to edit the machine's layer.

## The time zone

- A time zone is an IANA name (`Europe/Paris`), never a fixed offset: the offset changes twice a year, the name stays.
- The list is the system's (`timedatectl list-timezones`), about 600 names, read once on a worker. Each name's offset
  now ("UTC+01:00") is computed on that worker too, from the system's tz database (`core:time/timezone`).
- The person searches it: the zones index is one more index of `search.odin` (a query on a worker, the newest answer
  shown). "paris", "new york" and "utc+9" find what they say: the search reads the name with its underscores as spaces,
  and the offset.
- Refused: a dropdown of 600 rows (the installer's, before), and a map (its picture and its hit test are more work than
  a search, for no fact a search lacks).
- The row shows the zone's local time next to its offset. That time is the interface's clock plus the offset, made for
  the rows on screen only.

## The language and the keyboard

- The language is one of the installer's languages (`LANGUAGES`), by its locale. A locale outside that list (set by
  hand) shows as it is and stays until the person picks another.
- The keyboard is one of the installer's keyboards (`KEYBOARDS`), by its XKB layout, the same way.
- Both lists are short (ten, thirteen): a dropdown each.
