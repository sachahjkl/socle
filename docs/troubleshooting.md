# When something fails

## The window

**"The configuration does not evaluate".** Nix cannot read the folder. The page shows Nix's own words. The usual
causes: a file in `custom/` with an error, or a template link whose address does not answer. Fix the file, or click
**Discard** to go back to the last applied version.

**The dot in the bottom bar is red.** Your last change makes a system that does not evaluate. Open the review to read
why, change the value back, or click **Discard**.

**"An administrator's password is needed".** The apply needs an account of the group `wheel`. Without a polkit agent
(a window manager with no desktop), start one, for example `polkit-gnome` or `lxqt-policykit`.

**No window opens.** Socle draws with Vulkan, in a graphical session. Check that `vulkaninfo --summary` shows a device.
A machine with no desktop (Home Server, Minimal) has no session for the window: turn a desktop on, or use
[the folder](folder.md) and its commands.

## The apply

**The build fails.** The review shows Nix's error. A package that is not free needs its licence accepted on **Apps**.
A download that fails: check the network, then apply again.

**The new version broke the screen or the network.** Do nothing: 60 seconds after the try, the version before runs
again by itself.

**The machine does not start.** Choose an earlier version in the boot menu: each version is an entry. Then, in Socle,
**History → Go back to it** makes it the default again.

**"No version is on trial".** The timer already went back. Apply again.

## The install

**"This machine started in legacy BIOS mode".** Turn on UEFI in the firmware's settings, and start the stick's UEFI
entry. Legacy BIOS is not supported yet.

**"... is in use".** The chosen disk holds something mounted: it is the install medium, or a disk in use. Choose
another disk.

**The download stops.** The install needs the network for its whole length. Check it on the Network step, then click
**Back to the review** and install again. An install that stops leaves the disk free for the next try.

**The computer refuses the stick.** Turn Secure Boot off in the firmware's settings.

## Report a problem

Open an [issue](https://github.com/sachahjkl/socle/issues) with:

- what you did, and what Socle said (a screenshot of the window);
- `socle version`;
- for a failed apply: `journalctl -b -u 'socle-*' --no-pager`;
- for a failed install: the install's last lines in the window.
