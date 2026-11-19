#+build !linux
package socle

// The helper switches NixOS systems only: elsewhere there is nothing to keep apart.
helper_lock :: proc(path: cstring) -> bool { return true }
