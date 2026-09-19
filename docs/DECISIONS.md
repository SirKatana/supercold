# Decisions

One line per call made in auto mode, with why.

- M0: added physics layer 7 `flying_items`. Bullets must be blocked by thrown items but not by resting pickups, and a separate layer is the cheapest way to tell them apart.
- M0: accent colour `#7fe8ff` (cold cyan) for the elevator and interact highlights. White, pink and black alone gave no way to mark "go here".
- M0: `godot4 --headless --import` always prints `ERROR: Parameter "singleton" is null ... is_cmdline_mode`. It is engine noise from the editor bootstrap, exit code is 0, ignore it.
- M0: verified autoloads and the `Logger` API work under `-s`. The test runner installs a Logger and fails any test during which the engine logs an error.
- M1: frames are captured by the game itself (`godot4 --path . -- --shot=<png> --shot-after=<s> --level=<name>`), not by the desktop screenshot tool in the game-development skill. It needs no window focus and sends no keystrokes to the user's desktop.
- M1: level parser and the wall/floor/prop part of the builder were pulled forward from M4, because the M1 test room is already an ASCII level.
- M1: added legend characters `B` (boss spawn), `l` (stapler) and space (void, no floor). The plan's legend had no way to place the Director or the stapler.
- M1: time only advances from real horizontal velocity, so pushing into a wall does not move the clock.
