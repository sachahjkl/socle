package socle

// The demo system: what the window shows before socle drives a real configuration (ROADMAP.md, "Now"). The same data
// at each run, so a picture or a film is the same each time. Nothing here reads the disk.

import "gt:draw"

HOST_NAME     :: "house-laptop"
TEMPLATE_NAME :: "Family desktop"
FIRST_VERSION :: 214

// A package of the catalogue: its name, what it does, its version, the letter and colour of its tile, its category,
// whether its licence is free, and whether the template adds it.
Package :: struct {
	name, about, version: string,
	letter:   string,
	colour:   [3]f32,
	category: Category,
	unfree:   bool,
	template: bool,
}

Category :: enum { Internet, Office, Video, Graphics, Games, Development }

CATEGORY_TITLES := [Category]string{
	.Internet = "Internet", .Office = "Office", .Video = "Video and sound", .Graphics = "Graphics", .Games = "Games",
	.Development = "Development",
}

CATALOGUE := [?]Package{
	{"Firefox", "Browse the web", "145.0.1", "F", {0.88, 0.42, 0.13}, .Internet, false, true},
	{"Thunderbird", "Mail, calendars and contacts", "140.5.0", "T", {0.17, 0.42, 0.76}, .Internet, false, false},
	{"LibreOffice", "Documents, spreadsheets and slides", "25.8.3", "L", {0.12, 0.55, 0.32}, .Office, false, true},
	{"OBS Studio", "Record and stream the screen, a camera and sound", "32.0.2", "O", {0.24, 0.24, 0.32}, .Video, false, false},
	{"VLC", "Play any video and any sound", "3.0.21", "V", {0.85, 0.42, 0.10}, .Video, false, true},
	{"Kdenlive", "Edit videos: tracks, transitions, titles, effects", "25.08.3", "K", {0.18, 0.40, 0.60}, .Video, false, false},
	{"mpv", "A small video player driven by the keyboard", "0.41.0", "m", {0.40, 0.25, 0.52}, .Video, false, false},
	{"Shotcut", "Edit videos, from a clip to a film", "25.10.31", "S", {0.12, 0.45, 0.40}, .Video, false, false},
	{"DaVinci Resolve", "Professional editing, colour, effects and sound", "20.2.1", "D", {0.20, 0.20, 0.22}, .Video, true, false},
	{"Audacity", "Record and edit sound", "3.7.5", "A", {0.26, 0.38, 0.18}, .Video, false, true},
	{"Krita", "Paint and draw", "5.2.11", "K", {0.55, 0.22, 0.45}, .Graphics, false, true},
	{"GIMP", "Edit photos and pictures", "3.0.6", "G", {0.42, 0.36, 0.28}, .Graphics, false, false},
	{"Steam", "Games and their store", "1.0.0.85", "S", {0.10, 0.17, 0.30}, .Games, true, false},
	{"SuperTuxKart", "Kart races for the whole family", "1.5", "S", {0.20, 0.50, 0.20}, .Games, false, true},
	{"VS Code", "Edit code", "1.106.2", "C", {0.13, 0.45, 0.80}, .Development, true, false},
}

// The desktops a person can choose, with what each is.
DESKTOPS := [?]string{"Plasma", "GNOME", "COSMIC", "None"}
DESKTOP_ABOUT := [?]string{
	"KDE's desktop: a panel at the bottom, windows as on most computers, every detail can be changed.",
	"A calm desktop: one bar at the top, the apps and the windows in one overview.",
	"System76's desktop: windows that tile by themselves, or float.",
	"No desktop: a console, for a server.",
}
TEMPLATE_DESKTOP :: 1   // (GNOME: the template's choice)

PEOPLE := [?]string{"Sacha", "Lou", "Noé"}
LOCKS  := [?]string{"Never", "5 minutes", "15 minutes"}

// The settings that the window changes: the draft, the applied version and the template's are each one of these.
Settings :: struct {
	desktop:    int,
	dark:       bool,
	auto_login: bool,
	login_as:   int,
	lock_after: int,
	installed:  [len(CATALOGUE)]bool,
}

// The template's values: what "Back to the template" brings back.
template_settings :: proc() -> (s: Settings) {
	s.desktop, s.dark, s.auto_login, s.login_as, s.lock_after = TEMPLATE_DESKTOP, true, false, 1, 1
	for p, i in CATALOGUE { s.installed[i] = p.template }
	return
}

// The running system of the demo: the template, with Krita added (version 214).
demo_settings :: proc() -> Settings {
	return template_settings()
}

// A version of the system in the history.
Version :: struct {
	number:        int,
	date, title:   string,
	detail:        string,
	outside:       bool,   // made by a nixos-rebuild by hand: no settings to compare
}

demo_history :: proc() -> [dynamic]Version {
	h := make([dynamic]Version)
	append(&h,
		Version{214, "Today, 09:12", "Added Krita", "Apps · 1 change · 120 MB", false},
		Version{213, "16 November", "Noé's account: limits on school days", "People · 2 hours a day, Monday to Friday", false},
		Version{212, "12 November", "Software catalogue of 11 November", "Updates · 312 packages · kernel 6.18.6", false},
		Version{211, "9 November", "Made outside socle", "A nixos-rebuild by hand: no settings to compare", true},
		Version{210, "2 November", "The printer in the living room", "Printing · Brother HL-L2350, the default printer", false},
		Version{209, "28 October", "Template Family desktop 1.3", "Updates · parental limits for the children's accounts", false},
	)
	return h
}

// A template of the gallery: its title, what it is, where it comes from, its preview's two colours.
Template :: struct {
	title, about, source: string,
	top, bottom:          [3]f32,
	in_use, yours:        bool,
}

TEMPLATES := [?]Template{
	{"Family desktop", "A browser, an office suite, games, parental limits for the children's accounts.", "socle · 1.3", {0.11, 0.21, 0.34}, {0.27, 0.48, 0.62}, true, false},
	{"Gaming machine", "Extends Family desktop: Steam, controllers, the graphics drivers, a low-latency kernel.", "socle · 1.1", {0.18, 0.06, 0.25}, {0.56, 0.18, 0.38}, false, false},
	{"Developer workstation", "Editors, containers, a tiling desktop, Git and the usual tools of a developer.", "socle · 2.0", {0.06, 0.13, 0.15}, {0.17, 0.33, 0.39}, false, false},
	{"Home server", "Photos, films, files and backups for the household, reached from every device.", "socle · 1.0", {0.07, 0.07, 0.07}, {0.13, 0.17, 0.13}, false, false},
	{"Minimal", "A system that starts, a network, an account. Everything else is your choice.", "socle · 1.0", {0.08, 0.08, 0.08}, {0.15, 0.15, 0.15}, false, false},
	{"Ma maison", "Saved from house-desktop: Family desktop with the printer, the shares and 12 more apps.", "github:sachahjkl/ma-maison", {0.23, 0.17, 0.11}, {0.49, 0.35, 0.18}, false, true},
}

// An option of All settings: its path, its type, its description, and who sets it.
Option :: struct {
	path, type, about: string,
	default, value:    string,
	template, yours:   string,   // the template's value and the person's ("": none)
}

OPTIONS := [?]Option{
	{"services.printing.enable", "boolean", "Whether to enable printing support through the CUPS daemon.", "off", "on", "on", "on"},
	{"services.printing.drivers", "list of packages", "CUPS drivers to use.", "[ ]", "[ brlaser ]", "", "[ brlaser ]"},
	{"services.printing.browsing", "boolean", "Advertise shared printers.", "off", "off", "", ""},
	{"services.printing.defaultShared", "boolean", "Whether local printers are shared by default.", "off", "off", "", ""},
	{"services.printing.webInterface", "boolean", "Whether the web interface is enabled.", "on", "on", "", ""},
	{"hardware.printers.ensurePrinters", "list of printers", "Declares the printers that must exist.", "[ ]", "[ living-room ]", "", "[ living-room ]"},
	{"socle.printing.printers", "set of printers", "The printers of this machine, found on the network.", "{ }", "{ living-room }", "", "{ living-room }"},
	{"services.ipp-usb.enable", "boolean", "Enable IPP over USB for printers and scanners.", "off", "on", "on", ""},
}

colour :: proc(c: [3]f32, alpha: f32 = 1) -> draw.Color { return draw.srgb(c.x, c.y, c.z, alpha) }
