package socle

import "core:sys/linux"

// One verb at a time: the countdown's revert and a new try must not switch together (switch-to-configuration takes
// its own lock and fails the second). The kernel lets go of a flock when the process ends, crashed or not, so a dead
// helper never blocks the next one. The descriptor stays open until the process ends.
helper_lock :: proc(path: cstring) -> bool {
	fd, err := linux.open(path, {.CREAT, .RDWR, .CLOEXEC}, {.IRUSR, .IWUSR})
	if err != .NONE { return false }
	return linux.flock(fd, {.EX}) == .NONE
}
