package socletool

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import cli "gt:cli"
import toolbox "gt:toolbox"

MOCKUPS :: "docs/mockups"

// The screens are HTML so that a design can change in minutes, before any window code exists. Chromium draws each one
// headless at the window's size, so no window opens on the desktop.
mockups_run :: proc(args: []string) -> cli.Exit {
	browser := os.get_env("CHROMIUM", context.temp_allocator)
	if browser == "" { browser = "chromium" }
	entries, err := os.read_all_directory_by_path(MOCKUPS, context.temp_allocator)
	if err != nil { return toolbox.done(fmt.tprintf("%s cannot be read", MOCKUPS)) }
	pages := make([dynamic]string, context.temp_allocator)
	for e in entries {
		if e.type != .Directory && strings.has_suffix(e.name, ".html") { append(&pages, e.name) }
	}
	slice.sort(pages[:])
	root, _ := os.get_working_directory(context.temp_allocator)
	for name in pages {
		if len(args) > 0 && !slice.contains(args, strings.trim_suffix(name, ".html")) { continue }
		png := fmt.tprintf("%s/%s/%s.png", root, MOCKUPS, strings.trim_suffix(name, ".html"))
		url := fmt.tprintf("file://%s/%s/%s", root, MOCKUPS, name)
		command := []string{
			browser, "--headless", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
			"--window-size=1280,800", "--virtual-time-budget=2000", fmt.tprintf("--screenshot=%s", png), url,
		}
		if !toolbox.run(command, {log = "build/mockups.log"}) { return toolbox.done(fmt.tprintf("%s: see build/mockups.log", name)) }
		fmt.println(png)
	}
	return .Done
}
