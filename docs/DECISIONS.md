# Decisions

One line per call made in auto mode, with why.

- M0: added physics layer 7 `flying_items`. Bullets must be blocked by thrown items but not by resting pickups, and a separate layer is the cheapest way to tell them apart.
- M0: accent colour `#7fe8ff` (cold cyan) for the elevator and interact highlights. White, pink and black alone gave no way to mark "go here".
- M0: `godot4 --headless --import` always prints `ERROR: Parameter "singleton" is null ... is_cmdline_mode`. It is engine noise from the editor bootstrap, exit code is 0, ignore it.
- M0: verified autoloads and the `Logger` API work under `-s`. The test runner installs a Logger and fails any test during which the engine logs an error.
