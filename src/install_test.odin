package socle

import "core:fmt"
import "core:os"
import "core:strings"
import "core:testing"

// The machine layer that the install test installs (nix/tests.nix): the installer writes it, to the byte.
@(private = "file")
INSTALL_MACHINE :: #load("../tests/install/socle/hosts/socle-test.json", string)

@(private = "file")
install_plan :: proc() -> Plan {
	return {
		host = "socle-test", template = "socle#minimal", locale = "fr_FR.UTF-8", keyboard = "fr", zone = "Europe/Paris",
		login = "ada", name = "Ada", hash = "$y$j9T$Wu3003o05dV3UWB8Thm4K1$wpgv4qqakmfXmQiLFqoqf8vZljJ.qzNGeVI2mJDJvG1",
		disk = "/dev/vda", release = "26.05",
	}
}

@(test)
plan_writes_the_folder_that_the_install_test_installs :: proc(t: ^testing.T) {
	tmp := os.get_env("TMPDIR", context.temp_allocator)
	dir := fmt.tprintf("%s/socle-plan-test-%d", tmp != "" ? tmp : "/tmp", os.get_pid())
	defer os.remove_all(dir)
	why := plan_write(dir, install_plan())
	testing.expectf(t, why == "", "plan_write: %s", why)
	machine := read_text(join(dir, "socle", "hosts", "socle-test.json"), context.temp_allocator)
	testing.expect_value(t, machine, INSTALL_MACHINE)
	system := layer_parse(read_text(join(dir, "socle", "system.json"), context.temp_allocator))
	defer layer_destroy(&system)
	testing.expect_value(t, layer_template(system), "socle#minimal")
	testing.expect(t, bool_of(layer_get(system, {"socle", "people", "ada", "admin"})))
	// (the password's hash stays in the machine's layer)
	testing.expect(t, !strings.contains(read_text(join(dir, "socle", "system.json"), context.temp_allocator), "$y$"))
	flake := read_text(join(dir, "flake.nix"), context.temp_allocator)
	testing.expect(t, strings.contains(flake, SOCLE_URL) && strings.contains(flake, NIXPKGS_URL))
	// (a folder that holds a configuration is never written over)
	testing.expect(t, plan_write(dir, install_plan()) != "")
}

@(test)
plan_check_refuses_what_cannot_install :: proc(t: ^testing.T) {
	ok := install_plan()
	testing.expect_value(t, plan_check(ok), "")
	bad := ok
	bad.login = "Ada"
	testing.expect(t, plan_check(bad) != "")
	bad = ok
	bad.host = "my_laptop"
	testing.expect(t, plan_check(bad) != "")
	bad = ok
	bad.encrypt, bad.passphrase = true, "short"
	testing.expect(t, plan_check(bad) != "")
	bad = ok
	bad.disk = "vda"
	testing.expect(t, plan_check(bad) != "")
}
