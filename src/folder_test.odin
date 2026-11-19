package socle

import "core:os"
import "core:strings"
import "core:testing"

// A real folder of socle's, read as the window reads it: its evaluation by nix, its versions, its sources. Opt-in
// (SOCLE_FOLDER_TEST=<folder>: a folder with a flake, made by hand or by the VM's seed): it runs nix for seconds.
// It reads; it never builds or switches.
@(test)
a_folder_evaluates_and_reads :: proc(t: ^testing.T) {
	folder := os.get_env("SOCLE_FOLDER_TEST", context.temp_allocator)
	if folder == "" { return }
	host := pick_host_for_test(folder)
	testing.expect(t, host != "", "the folder has a machine")
	text, why := evaluate(folder, host)
	testing.expectf(t, why == "", "the folder evaluates: %s", why)
	info, perr := info_parse(text)
	testing.expectf(t, info != nil, "its evaluation reads: %s", perr)
	defer info_destroy(info)
	testing.expect(t, len(info.popular) > 10, "the popular apps come with it")
	testing.expect(t, len(info.pages) > 5, "the pages come with it")
	testing.expect(t, info.nixpkgs != "", "the locked Nixpkgs is named")
	testing.expect(t, str(at(info.effective, {"desktop", "environment"})) != "", "socle's values are there")
	locks := lock_dates(read_text(join(folder, "flake.lock"), context.temp_allocator))
	testing.expect(t, locks["nixpkgs"] > 0, "the lock gives Nixpkgs's date")
	gens := generations_read(folder, host)
	defer generations_destroy(&gens)
	running := 0
	for g in gens { if g.running { running += 1 } }
	testing.expect(t, len(gens) == 0 || running <= 1, "at most one version runs")
	delete(text)
	for k in locks { delete(k) }
	delete(locks)
}

@(private = "file")
pick_host_for_test :: proc(folder: string) -> string {
	entries, err := os.read_all_directory_by_path(join(folder, "socle", "hosts"), context.temp_allocator)
	if err != nil { return "" }
	for e in entries { if strings.has_suffix(e.name, ".json") { return strings.trim_suffix(e.name, ".json") } }
	return ""
}
